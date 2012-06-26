!^CFG COPYRIGHT UM
!==============================================================================
module ModUser
  use ModSize, ONLY: MinI, MaxI, MinJ, MaxJ, MinK, MaxK, MaxBlock
  use ModUserEmpty,                                     &
       IMPLEMENTED1 => user_read_inputs,                &
       IMPLEMENTED2 => user_init_session,               &
       IMPLEMENTED3 => user_set_ics,                    &
       IMPLEMENTED4 => user_get_log_var,                &
       IMPLEMENTED5 => user_calc_sources,               &
       IMPLEMENTED6 => user_set_plot_var,               &
       IMPLEMENTED7 => user_set_cell_boundary,               &
       IMPLEMENTED8 => user_set_face_boundary,                   &
       IMPLEMENTED9 => user_set_resistivity,            &
       IMPLEMENTED10=> user_update_states

  include 'user_module.h' !list of public methods

  real, parameter :: VersionUserModule = 1.0
  character (len=*), parameter :: NameUserModule = &
       'Two-temperature solar wind with Alfven waves - van der Holst'

  logical ::  UseWaveDissipation = .false.
  real :: DissipationScaleFactorSi  ! unit = m*T^0.5
  real :: DissipationScaleFactor

  ! variables for wave BC's
  logical :: UseScaledWaveBcs = .false.
  real :: WaveEnergyFactor = 0.0, WaveEnergyPower = 1./3.
  real :: ExpFactorInvMin = 1e-3

  real :: TeFraction, TiFraction
  real :: EtaPerpSi

  real :: QeByQtotal = 0.0

  ! Variables for the Bernoulli equation
  logical :: UseHeatFluxInBernoulli = .false.
  logical :: IsNewBlockTe_B(MaxBlock) = .true.
  real :: HeatCondPar
  real :: Te_G(MinI:MaxI,MinJ:MaxJ,MinK:MaxK)
  real :: VAlfvenMin = 1.0e5  !100 km/s
  real :: RhoVAt1AU = 4.5e-15 !kg/(m2*s) ! in fast wind NpV=2.7x10^8 /cm2s

contains

  !============================================================================

  subroutine user_read_inputs

    use ModMain,      ONLY: UseUserInitSession, lVerbose
    use ModProcMH,    ONLY: iProc
    use ModReadParam, ONLY: read_line, read_command, read_var
    use ModIO,        ONLY: write_prefix, write_myname, iUnitOut

    character (len=100) :: NameCommand
    character(len=*), parameter :: NameSub = 'user_read_inputs'
    !--------------------------------------------------------------------------
    UseUserInitSession = .true.

    if(iProc == 0 .and. lVerbose > 0)then
       call write_prefix;
       write(iUnitOut,*)'User read_input SOLAR CORONA starts'
    endif

    do
       if(.not.read_line() ) EXIT
       if(.not.read_command(NameCommand)) CYCLE

       select case(NameCommand)

       case("#WAVEDISSIPATION")
          call read_var('UseWaveDissipation', UseWaveDissipation)
          if(UseWaveDissipation) &
               call read_var('DissipationScaleFactorSi', &
               DissipationScaleFactorSi)

       case("#WAVEBOUNDARY")
          call read_var('UseScaledWaveBcs', UseScaledWaveBcs)
          if(UseScaledWaveBcs) then
             call read_var('WaveEnergyFactor', WaveEnergyFactor)
             call read_var('WaveEnergyPower', WaveEnergyPower)
             call read_var('ExpFactorInvMin', ExpFactorInvMin)
          end if

       case('#BERNOULLI')
          ! It is not advised to use the time-dependent heat flux in the
          ! Bernoulli function.
          call read_var('UseHeatFluxInBernoulli', UseHeatFluxInBernoulli)
          call read_var('VAlfvenMin', VAlfvenMin)
          call read_var('RhoVAt1AU', RhoVAt1AU)

       case('#ELECTRONHEATING')
          ! Steven Cranmer his electron heating fraction (Apj 2009)
          call read_var('QeByQtotal', QeByQtotal)

       case('#USERINPUTEND')
          if(iProc == 0 .and. lVerbose > 0)then
             call write_prefix;
             write(iUnitOut,*)'User read_input SOLAR CORONA ends'
          endif
          EXIT

       case default
          if(iProc == 0) then
             call write_myname; write(*,*) &
                  'ERROR: Invalid user defined #COMMAND in user_read_inputs. '
             write(*,*) '--Check user_read_inputs for errors'
             write(*,*) '--Check to make sure a #USERINPUTEND command was used'
             write(*,*) '  *Unrecognized command was: '//NameCommand
             call stop_mpi('ERROR: Correct PARAM.in or user_read_inputs!')
          end if
       end select
    end do

  end subroutine user_read_inputs

  !============================================================================

  subroutine user_init_session

    use ModAdvance,     ONLY: UseElectronPressure
    use ModConst,       ONLY: cElectronCharge, cLightSpeed, cBoltzmann, cEps, &
         cElectronMass
    use ModExpansionFactors, ONLY: WSAspeed_N
    use ModIO,          ONLY: write_prefix, iUnitOut
    use ModLdem,        ONLY: read_ldem, UseLdem
    use ModMain,        ONLY: NameThisComp
    use ModMultiFluid,  ONLY: MassIon_I
    use ModNumConst,    ONLY: cTwoPi
    use ModPhysics,     ONLY: ElectronTemperatureRatio, AverageIonCharge, &
         Si2No_V, UnitB_, UnitX_, UnitU_, UnitEnergyDens_, UnitTemperature_
    use ModProcMH,      ONLY: iProc
    use ModReadParam,   ONLY: i_session_read
    use ModWaves,       ONLY: UseWavePressure, UseAlfvenWaves

    real :: HeatCondParSi
    real, parameter :: CoulombLog = 20.0
    !--------------------------------------------------------------------------
    if(iProc == 0)then
       call write_prefix; write(iUnitOut,*) ''
       call write_prefix; write(iUnitOut,*) 'user_init_session:'
       call write_prefix; write(iUnitOut,*) ''
    end if

    UseAlfvenWaves = .true.
    UseWavePressure = .true.

    ! TeFraction is used for ideal EOS:
    if(UseElectronPressure)then
       ! Pe = ne*Te (dimensionless) and n=rho/ionmass
       ! so that Pe = ne/n *n*Te = (ne/n)*(rho/ionmass)*Te
       ! TeFraction is defined such that Te = Pe/rho * TeFraction
       TiFraction = MassIon_I(1)
       TeFraction = MassIon_I(1)/AverageIonCharge
    else
       ! p = n*T + ne*Te (dimensionless) and n=rho/ionmass
       ! so that p=rho/massion *T*(1+ne/n Te/T)
       ! TeFraction is defined such that Te = p/rho * TeFraction
       TiFraction = MassIon_I(1) &
            /(1 + AverageIonCharge*ElectronTemperatureRatio)
       TeFraction = TiFraction*ElectronTemperatureRatio
    end if

    ! perpendicular resistivity, used for temperature relaxation
    ! Note EtaPerpSi is divided by cMu.
    EtaPerpSi = sqrt(cElectronMass)*CoulombLog &
         *(cElectronCharge*cLightSpeed)**2/(3*(cTwoPi*cBoltzmann)**1.5*cEps)

    DissipationScaleFactor = DissipationScaleFactorSi*Si2No_V(UnitX_) &
         *sqrt(Si2No_V(UnitB_))

    ! electron heat conduct coefficient for single charged ions
    ! = 9.2e-12 W/(m*K^(7/2))
    HeatCondParSi = 3.2*3.0*cTwoPi/CoulombLog &
         *sqrt(cTwoPi*cBoltzmann/cElectronMass)*cBoltzmann &
         *((cEps/cElectronCharge)*(cBoltzmann/cElectronCharge))**2

    ! unit HeatCondParSi is W/(m*K^(7/2))
    HeatCondPar = HeatCondParSi &
         *Si2No_V(UnitEnergyDens_)/Si2No_V(UnitTemperature_)**3.5 &
         *Si2No_V(UnitU_)*Si2No_V(UnitX_)

    if(NameThisComp == 'SC' .and. i_session_read()==1)then
       if(iProc == 0) call write_alfvenwave_boundary
    end if

    if(iProc == 0)then
       call write_prefix; write(iUnitOut,*) ''
       call write_prefix; write(iUnitOut,*) 'user_init_session finished'
       call write_prefix; write(iUnitOut,*) ''
    end if

  end subroutine user_init_session

  !============================================================================

  subroutine write_alfvenwave_boundary

    use ModExpansionFactors, ONLY: H_PFSSM
    use ModIO,          ONLY: NamePlotDir
    use ModMagnetogram, ONLY: r_latitude, dPhi, nTheta, nPhi
    use ModNumConst,    ONLY: cRadToDeg
    use ModPhysics,     ONLY: rBody, No2Si_V, UnitP_, UnitU_, &
         UnitEnergyDens_, UnitB_, UnitRho_
    use ModPlotFile,    ONLY: save_plot_file
    use ModWaves,       ONLY: GammaWave
    use ModB0,          ONLY: get_b0

    integer :: iPhi, iTheta
    real :: r, Theta, Phi, Xyz_D(3)
    real :: RhoBase, Tbase, Br, Btot, B0_D(3)
    real :: Ewave, DeltaU, HeatFlux
    real, allocatable :: Coord_DII(:,:,:), State_VII(:,:,:)
    character(len=32) :: FileNameOut
    !--------------------------------------------------------------------------
    FileNameOut = trim(NamePlotDir)//'Alfvenwave.outs'

    allocate(Coord_DII(2,0:nPhi,0:nTheta), State_VII(6,0:nPhi,0:nTheta))

    do iTheta = 0, nTheta
       do iPhi = 0, nPhi
          r     = rBody + H_PFSSM
          Theta = r_latitude(iTheta)
          Phi   = real(iPhi)*dPhi

          Coord_DII(1,iPhi,iTheta) = Phi*cRadToDeg
          Coord_DII(2,iPhi,iTheta) = Theta*cRadToDeg

          Xyz_D = &
               (/ r*cos(Theta)*cos(Phi), r*cos(Theta)*sin(Phi), r*sin(Theta)/)

          call get_b0(Xyz_D, B0_D)
          Br   = sum(Xyz_D*B0_D)/r
          Btot = sqrt(sum(B0_D**2))
          call get_plasma_parameters_base(Xyz_D, RhoBase, Tbase)

          HeatFlux = 0.0
          call get_wave_energy(Xyz_D(1), Xyz_D(2), Xyz_D(3), &
               Br, Btot, HeatFlux, Ewave)
          ! Root mean square amplitude of the velocity fluctuation
          ! This assumes equipartition (of magnetic and velocity fluctuations)
          DeltaU = sqrt(Ewave/RhoBase)

          State_VII(1,iPhi,iTheta) = (GammaWave - 1)*Ewave*No2Si_V(UnitP_)
          State_VII(2,iPhi,iTheta) = DeltaU*No2Si_V(UnitU_)
          State_VII(3,iPhi,iTheta) = Ewave*abs(Br)/sqrt(Rhobase) &
               *No2Si_V(UnitEnergyDens_)*No2Si_V(UnitU_)
          State_VII(4,iPhi,iTheta) = Br*No2Si_V(UnitB_)*1e4
          State_VII(5,iPhi,iTheta) = Btot*No2Si_V(UnitB_)*1e4
          State_VII(6,iPhi,iTheta) = RhoBase*No2Si_V(UnitRho_)

       end do
    end do

    call save_plot_file(FileNameOut, nDimIn=2, StringHeaderIn = &
         'Longitude [Deg], Latitude [Deg], Pwave [Pa], DeltaU [m/s] ' &
         //'Ewaveflux [J/(m^2s)], Br [Gauss], Btot [Gauss], Rho [kg/m^3]', &
         nameVarIn = 'Longitude Latitude Pwave DeltaU Ewaveflux Br Btot Rho', &
         CoordIn_DII=Coord_DII, VarIn_VII=State_VII)

    deallocate(Coord_DII, State_VII)

  end subroutine Write_alfvenwave_boundary

  !============================================================================

  subroutine get_plasma_parameters_base(x_D, RhoBase, Tbase)

    ! This subroutine computes the base values for mass density and temperature

    use ModLdem,             ONLY: get_ldem_moments, UseLdem
    use ModPhysics,          ONLY: BodyRho_I, Si2No_V, UnitTemperature_, UnitN_, &
                                   AverageIonCharge
    use ModExpansionFactors, ONLY: Umin, CoronalT0Dim
    use ModMultiFluid,       ONLY: MassIon_I

    real, intent(in) :: x_D(3)
    real, intent(out):: RhoBase, Tbase

    ! Electron density and temperature from ldem moments (cm^-3, MK respectively)
    real :: Ne, Te
    ! The solar wind speed at the far end of the Parker spiral,
    ! which originates from the given point.
    real :: Ufinal
    ! The coronal based values for temperature and density
    ! are scaled as functions of UFinal/UMin ratio.
    real :: Uratio
    real :: Runit_D(3)
    !--------------------------------------------------------------------------
    if(UseLdem)then
       call get_ldem_moments(x_D, Ne, Te)
       RhoBase = Ne*Si2No_V(UnitN_)*MassIon_I(1)/AverageIonCharge
       Tbase = Te*Si2No_V(UnitTemperature_)

       RETURN
    end if

    Runit_D = x_D/sqrt(sum(x_D**2))

    call get_bernoulli_integral(Runit_D, Ufinal)
    Uratio = Ufinal/Umin

    ! This is the temperature variation.
    ! In coronal holes the temperature is reduced 
    Tbase = CoronalT0Dim*Si2No_V(UnitTemperature_) / min(Uratio, 1.5)

    ! This is the density variation
    RhoBase = BodyRho_I(1)/URatio

  end subroutine get_plasma_parameters_base

  !============================================================================

  subroutine get_wave_energy(x, y, z, Br, Btot, HeatFlux, Ewave)

    ! Provides the distribution of the total Alfven wave energy density
    ! at the lower boundary

    use ModExpansionFactors
    use ModMultiFluid, ONLY: MassIon_I
    use ModNumConst,   ONLY: cTolerance
    use ModPhysics,    ONLY: g, inv_gm1, rBody, AverageIonCharge, &
         Si2No_V, No2Si_V, UnitU_, UnitTemperature_, UnitEnergyDens_, UnitB_

    real, intent(in) :: x, y, z, Br, Btot, HeatFlux
    real, intent(out):: Ewave

    real :: ExpansionFactorInv, Uf, Uratio, dTedr, DeltaU
    real :: RhoBase, Tbase, TbaseSi, HeatFluxSi, WaveEnergyDensSi
    real :: VAlfvenSi
    real :: RhoV
    real :: Xyz_D(3)
    real, parameter :: Umax = 8e5 ! 800 km/s
    real, parameter :: AreaRatio = (cAU/rSun)**2
    !--------------------------------------------------------------------------

    ! Inverse expansion factor
    ! Note the slight inconsistency, since the expansion factor is not the
    ! true expansion factor at rBody+PFSSM_Height as needed in the
    ! Bernoulli equation.
    call get_interpolated(ExpansionFactorInv_N, x, y, z, ExpansionFactorInv)
 
    Xyz_D = (/x, y, z/)
    call get_plasma_parameters_base(Xyz_D, RhoBase, Tbase) 

    Ewave = 0.0
     
    ! Closed field line regions can not support Alfven wave solutions
    ! (of the infinite domain)
    if(ExpansionFactorInv < ExpFactorInvMin) RETURN

    if(UseScaledWaveBcs)then
      
       Ewave = WaveEnergyFactor*(Btot)**WaveEnergyPower
    else

       VAlfvenSi = (Br/sqrt(RhoBase))*No2Si_V(UnitU_)
       TbaseSi = Tbase*No2Si_V(UnitTemperature_)

       if(UseHeatFluxInBernoulli)then
          HeatFluxSi = HeatFlux*No2Si_V(UnitEnergyDens_)*No2Si_V(UnitU_)
       else
          HeatFluxSi = 0.0
       end if

       !v_\infty from WSA model:
       call get_bernoulli_integral(Xyz_D, Uf)
       Uratio = Umax/Uf

       ! contrast ratio between mass flux in high and slow speed wind is here
       ! approximated by sqrt(Uratio)
       RhoV =  RhoVAt1AU*sqrt(Uratio)
       
       WaveEnergyDensSi = (RhoV*AreaRatio/rBody**2*(0.5*Uf**2 &
            + cSunGravitySi/rBody - g*inv_gm1*&
            cBoltzmann/(cProtonMass*MassIon_I(1))*(1.0+AverageIonCharge) &
            *TbaseSi) - ExpansionFactorInv*HeatFluxSi) &
            /max(abs(VAlfvenSi)*ExpansionFactorInv, VAlfvenMin)

       ! Make sure that the wave energy is never negative
       Ewave = max(WaveEnergyDensSi,0.0)*Si2No_V(UnitEnergyDens_)

    end if

  end subroutine get_wave_energy

  !============================================================================

  subroutine user_set_ics(iBlock)

    ! The isothermal parker wind solution is used as initial condition

    use ModAdvance,    ONLY: State_VGB, UseElectronPressure
    use ModGeometry,   ONLY: x_Blk, y_Blk, z_Blk, r_Blk, true_cell
    use ModMain,       ONLY: nI, nJ, nK
    use ModMultiFluid, ONLY: MassIon_I
    use ModPhysics,    ONLY: Si2No_V, UnitTemperature_, rBody, GBody, &
         BodyRho_I, BodyTDim_I, UnitU_, AverageIonCharge
    use ModVarIndexes, ONLY: Rho_, RhoUx_, RhoUy_, RhoUz_, Bx_, Bz_, p_, Pe_, &
         WaveFirst_, WaveLast_

    integer, intent(in) :: iBlock

    integer :: i, j, k
    integer :: IterCount
    real :: x, y, z, r, RhoBase, Rho, NumDensIon, NumDensElectron
    real :: Tcorona, Tbase, Temperature
    real :: Ur, Ur0, Ur1, del, Ubase, rTransonic, Uescape, Usound

    real, parameter :: Epsilon = 1.0e-6
    !--------------------------------------------------------------------------

    ! Initially, the electron and ion temperature are at 1.5e6(K) in the corona
    Tcorona = 1.5e6*Si2No_V(UnitTemperature_)

    ! normalize with isothermal sound speed.
    Usound = sqrt(Tcorona*(1.0+AverageIonCharge)/MassIon_I(1))
    Uescape = sqrt(-GBody*2.0)/Usound

    !\
    ! Initialize MHD wind with Parker's solution
    ! construct solution which obeys
    !   rho x u_r x r^2 = constant
    !/
    rTransonic = 0.25*Uescape**2
    if(.not.(rTransonic>exp(1.0))) call stop_mpi('sonic point inside Sun')

    Ubase = rTransonic**2*exp(1.5 - 2.0*rTransonic)

    do k = 1, nK; do j = 1, nJ; do i = 1, nI
       x = x_BLK(i,j,k,iBlock)
       y = y_BLK(i,j,k,iBlock)
       z = z_BLK(i,j,k,iBlock)
       r = r_BLK(i,j,k,iBlock)

       ! The electron and ion temperature are initially equal to
       ! the temperature at the base.
       call get_plasma_parameters_base((/x,y,z/), RhoBase, Tbase)

       if(r > rTransonic)then
          !\
          ! Inside supersonic region
          !/
          Ur0 = 1.0
          IterCount = 0
          do
             IterCount = IterCount + 1
             Ur1 = sqrt(Uescape**2/r - 3.0 + 2.0*log(16.0*Ur0*r**2/Uescape**4))
             del = abs(Ur1 - Ur0)
             if(del < Epsilon)then
                Ur = Ur1
                EXIT
             elseif(IterCount < 1000)then
                Ur0 = Ur1
                CYCLE
             else
                call stop_mpi('PARKER > 1000 it.')
             end if
          end do
       else
          !\
          ! Inside subsonic region
          !/
          Ur0 = 1.0
          IterCount = 0
          do
             IterCount = IterCount + 1
             Ur1 = (Uescape**2/(4.0*r))**2 &
                  *exp(0.5*(Ur0**2 + 3.0 - Uescape**2/r))
             del = abs(Ur1 - Ur0)
             if(del < Epsilon)then
                Ur = Ur1
                EXIT
             elseif(IterCount < 1000)then
                Ur0 = Ur1
                CYCLE
             else
                call stop_mpi('PARKER > 1000 it.')
             end if
          end do
       end if

       Rho = rBody**2*RhoBase*Ubase/(r**2*Ur)
       State_VGB(Rho_,i,j,k,iBlock) = Rho
       State_VGB(RhoUx_,i,j,k,iBlock) = Rho*Ur*x/r *Usound
       State_VGB(RhoUy_,i,j,k,iBlock) = Rho*Ur*y/r *Usound
       State_VGB(RhoUz_,i,j,k,iBlock) = Rho*Ur*z/r *Usound
       State_VGB(Bx_:Bz_,i,j,k,iBlock) = 0.0
       State_VGB(WaveFirst_:WaveLast_,i,j,k,iBlock) = 1.0e-12 !0.0
       NumDensIon = Rho/MassIon_I(1)
       NumDensElectron = NumDensIon*AverageIonCharge

       if(UseElectronPressure)then
          State_VGB(p_,i,j,k,iBlock) = NumDensIon*Tbase
          State_VGB(Pe_,i,j,k,iBlock) = NumDensElectron*Tbase
       else
          State_VGB(p_,i,j,k,iBlock) = &
               (NumDensIon + NumDensElectron)*Tbase
       end if
    end do; end do; end do

  end subroutine user_set_ics

  !============================================================================

  subroutine user_update_states(iStage, iBlock)

    integer, intent(in) :: iStage, iBlock
    !--------------------------------------------------------------------------
    call update_states_MHD(iStage, iBlock)

    if(UseHeatFluxInBernoulli) IsNewBlockTe_B(iBlock) = .true.

  end subroutine user_update_states

  !============================================================================

  subroutine user_calc_sources(iBlock)

    use ModAdvance,        ONLY: State_VGB, Source_VC, UseElectronPressure, &
         B0_DGB, VdtFace_x, VdtFace_y, VdtFace_z
    use ModGeometry,       ONLY: r_BLK
    use ModMain,           ONLY: nI, nJ, nK, UseB0
    use ModPhysics,        ONLY: gm1, rBody
    use ModVarIndexes,     ONLY: Rho_, Bx_, Bz_, Energy_, p_, Pe_, &
         WaveFirst_, WaveLast_
    use BATL_lib, ONLY: CellVolume_GB

    integer, intent(in) :: iBlock

    integer :: i, j, k, iWave
    real :: CoronalHeating
    real :: DissipationLength, WaveDissipation, FullB_D(3), FullB
    real :: DtInvWave, Vdt_Source, Vdt

    character (len=*), parameter :: NameSub = 'user_calc_sources'
    !--------------------------------------------------------------------------

    do k = 1, nK; do j = 1, nJ; do i = 1, nI
       if(r_BLK(i,j,k,iBlock) < rBody) CYCLE

       if(UseWaveDissipation)then
          if(UseB0)then
             FullB_D = B0_DGB(:,i,j,k,iBlock) + State_VGB(Bx_:Bz_,i,j,k,iBlock)
          else
             FullB_D = State_VGB(Bx_:Bz_,i,j,k,iBlock)
          end if
          FullB = sqrt(sum(FullB_D**2))
          DissipationLength = DissipationScaleFactor/sqrt(FullB)
          CoronalHeating = 0.0
          do iWave = WaveFirst_, WaveLast_
             WaveDissipation = State_VGB(iWave,i,j,k,iBlock)**1.5 &
                  /sqrt(State_VGB(Rho_,i,j,k,iBlock))/DissipationLength
             Source_VC(iWave,i,j,k) = Source_VC(iWave,i,j,k) - WaveDissipation
             CoronalHeating = CoronalHeating + WaveDissipation

             ! Simplistic time step control for large source terms.
             DtInvWave  = abs(WaveDissipation &
               /max(State_VGB(iWave,i,j,k,iBlock),1e-30))

             Vdt_Source = 2.0*DtInvWave*CellVolume_GB(i,j,k,iBlock)

             Vdt = min(VdtFace_x(i,j,k),VdtFace_y(i,j,k),VdtFace_z(i,j,k))

             if(Vdt_Source > Vdt)then
                ! The following prevents the wave energy from becoming negative
                ! due to too large source terms. This should be cell-centered,
                ! since the source are, but we add
                ! them for now to the left face of VdtFace.
                VdtFace_x(i,j,k) = max(VdtFace_x(i,j,k), Vdt_Source)
                VdtFace_y(i,j,k) = max(VdtFace_y(i,j,k), Vdt_Source)
                VdtFace_z(i,j,k) = max(VdtFace_z(i,j,k), Vdt_Source)
             end if
          end do
       else
          CoronalHeating = 0.0
       end if
       if(UseElectronPressure)then
          Source_VC(p_,i,j,k) = Source_VC(p_,i,j,k) &
               + gm1*(1.0 - QeByQtotal)*CoronalHeating
          ! The following needs a time step control
          Source_VC(Pe_,i,j,k) = Source_VC(Pe_,i,j,k) &
               + gm1*QeByQtotal*CoronalHeating
       else
          Source_VC(p_,i,j,k) = Source_VC(p_,i,j,k) + gm1*CoronalHeating
       end if

    end do; end do; end do

  end subroutine user_calc_sources

  !============================================================================

  subroutine user_get_log_var(VarValue, TypeVar, Radius)

    use ModAdvance,    ONLY: State_VGB, tmp1_BLK, B0_DGB, UseElectronPressure
    use ModIO,         ONLY: write_myname
    use ModMain,       ONLY: Unused_B, nBlock, x_, y_, z_, UseB0
    use ModPhysics,    ONLY: inv_gm1, No2Io_V, UnitEnergydens_, UnitX_
    use ModVarIndexes, ONLY: Bx_, By_, Bz_, p_, Pe_

    real, intent(out) :: VarValue
    character(len=10), intent(in) :: TypeVar 
    real, optional, intent(in) :: Radius

    integer :: iBlock
    real :: unit_energy
    real, external :: integrate_BLK
    !--------------------------------------------------------------------------
    unit_energy = No2Io_V(UnitEnergydens_)*No2Io_V(UnitX_)**3
    !\
    ! Define log variable to be saved::
    !/
    select case(TypeVar)
    case('eint')
       do iBlock = 1, nBlock
          if(Unused_B(iBlock)) CYCLE
          if(UseElectronPressure)then
             tmp1_BLK(:,:,:,iBlock) = &
                  State_VGB(p_,:,:,:,iBlock) + State_VGB(Pe_,:,:,:,iBlock)
          else
             tmp1_BLK(:,:,:,iBlock) = State_VGB(p_,:,:,:,iBlock)
          end if
       end do
       VarValue = unit_energy*inv_gm1*integrate_BLK(1,tmp1_BLK)

    case('emag')
       do iBlock = 1, nBlock
          if(Unused_B(iBlock)) CYCLE
          if(UseB0)then
             tmp1_BLK(:,:,:,iBlock) = & 
                  ( B0_DGB(x_,:,:,:,iBlock) + State_VGB(Bx_,:,:,:,iBlock))**2 &
                  +(B0_DGB(y_,:,:,:,iBlock) + State_VGB(By_,:,:,:,iBlock))**2 &
                  +(B0_DGB(z_,:,:,:,iBlock) + State_VGB(Bz_,:,:,:,iBlock))**2
          else
             tmp1_BLK(:,:,:,iBlock) = State_VGB(Bx_,:,:,:,iBlock)**2 &
                  + State_VGB(By_,:,:,:,iBlock)**2 &
                  + State_VGB(Bz_,:,:,:,iBlock)**2
          end if
       end do
       VarValue = unit_energy*0.5*integrate_BLK(1,tmp1_BLK)

    case('vol')
       tmp1_BLK(:,:,:,iBlock) = 1.0
       VarValue = integrate_BLK(1,tmp1_BLK)

    case default
       VarValue = -7777.
       call write_myname;
       write(*,*) 'Warning in set_user_logvar: unknown logvarname = ',TypeVar
    end select

  end subroutine user_get_log_var

  !============================================================================

  subroutine user_set_plot_var(iBlock, NameVar, IsDimensional, &
       PlotVar_G, PlotVarBody, UsePlotVarBody, &
       NameTecVar, NameTecUnit, NameIdlUnit, IsFound)

    use ModAdvance,    ONLY: State_VGB, UseElectronPressure, B0_DGB
    use ModMain,       ONLY: UseB0
    use ModNumConst,   ONLY: cTolerance
    use ModPhysics,    ONLY: No2Si_V, UnitTemperature_
    use ModSize,       ONLY: nI, nJ, nK
    use ModVarIndexes, ONLY: Rho_, p_, Pe_, Bx_, Bz_, WaveFirst_, WaveLast_

    integer,          intent(in)   :: iBlock
    character(len=*), intent(in)   :: NameVar
    logical,          intent(in)   :: IsDimensional
    real,             intent(out)  :: PlotVar_G(-1:nI+2, -1:nJ+2, -1:nK+2)
    real,             intent(out)  :: PlotVarBody
    logical,          intent(out)  :: UsePlotVarBody
    character(len=*), intent(inout):: NameTecVar
    character(len=*), intent(inout):: NameTecUnit
    character(len=*), intent(inout):: NameIdlUnit
    logical,          intent(out)  :: IsFound

    integer :: i, j, k
    real :: FullB, FullB2, p, Ewave

    character (len=*), parameter :: NameSub = 'user_set_plot_var'
    !--------------------------------------------------------------------------

    IsFound = .true.

    select case(NameVar)
    case('te')
       NameIdlUnit = 'K'
       do k = -1, nK+2; do j = -1, nJ+2; do i = -1, nI+2
          if(UseElectronPressure)then
             PlotVar_G(i,j,k) = TeFraction*State_VGB(Pe_,i,j,k,iBlock) &
                  /State_VGB(Rho_,i,j,k,iBlock)*No2Si_V(UnitTemperature_)
          else
             PlotVar_G(i,j,k) = TeFraction*State_VGB(p_,i,j,k,iBlock) &
                  /State_VGB(Rho_,i,j,k,iBlock)*No2Si_V(UnitTemperature_)
          end if
       end do; end do; end do

    case('ti')
       NameIdlUnit = 'K'
       do k = -1, nK+2; do j = -1, nJ+2; do i = -1, nI+2
          PlotVar_G(i,j,k) = TiFraction*State_VGB(p_,i,j,k,iBlock) &
               /State_VGB(Rho_,i,j,k,iBlock)*No2Si_V(UnitTemperature_)
       end do; end do; end do

    case('deltabperb')
       do k = -1, nK+2; do j = -1, nJ+2; do i = -1, nI+2
          if(UseB0)then
             FullB = sqrt(sum((B0_DGB(:,i,j,k,iBlock) &
                  + State_VGB(Bx_:Bz_,i,j,k,iBlock))**2))
          else
             FullB = sqrt(sum(State_VGB(Bx_:Bz_,i,j,k,iBlock)**2))
          end if
          Ewave = sum(State_VGB(WaveFirst_:WaveLast_,i,j,k,iBlock))
          PlotVar_G(i,j,k) = sqrt(Ewave)/max(FullB, cTolerance)
       end do; end do; end do

    case('beta')
       do k = -1, nK+2; do j = -1, nJ+2; do i = -1, nI+2
          if(UseB0)then
             FullB2 = sum((B0_DGB(:,i,j,k,iBlock) &
                  + State_VGB(Bx_:Bz_,i,j,k,iBlock))**2)
          else
             FullB2 = sum(State_VGB(Bx_:Bz_,i,j,k,iBlock)**2)
          end if
          if(UseElectronPressure)then
             p = State_VGB(p_,i,j,k,iBlock) + State_VGB(Pe_,i,j,k,iBlock)
          else
             p = State_VGB(p_,i,j,k,iBlock)
          end if
          PlotVar_G(i,j,k) = 2.0*p/max(FullB2, cTolerance)
       end do; end do; end do

    case default
       IsFound = .false.
    end select

    UsePlotVarBody = .false.
    PlotVarBody    = 0.0

  end subroutine user_set_plot_var

  !============================================================================

  subroutine user_set_cell_boundary(iBlock,iSide, TypeBc, IsFound)

    ! Fill one layer of ghost cells with the temperature for heat conduction

    use ModAdvance,    ONLY: State_VGB, UseElectronPressure
    use ModGeometry,   ONLY: x_Blk, y_Blk, z_Blk
    use ModMain,       ONLY: x_, y_, z_, nJ, nK
    use ModMultiFluid, ONLY: MassIon_I
    use ModPhysics,    ONLY: AverageIonCharge
    use ModVarIndexes, ONLY: Rho_, p_, Pe_
    use ModImplicit,   ONLY: StateSemi_VGB, iTeImpl

    integer,          intent(in)  :: iBlock, iSide
    character(len=20),intent(in)  :: TypeBc
    logical,          intent(out) :: IsFound

    integer :: i, j, k
    real :: x_D(3)
    real :: RhoBase, Tbase, NumDensIon, NumDensElectron

    character (len=*), parameter :: NameSub = 'user_set_cell_boundary'
    !--------------------------------------------------------------------------

    if(iSide /= 1) call stop_mpi('Wrong iSide in user_set_cell_boundary')

    IsFound = .true.

    if(TypeBc == 'usersemilinear')then
       RETURN
    end if

    do k = -1, nK+2; do j = -1, nJ+2
       x_D(x_) = 0.5*sum(x_Blk(0:1,j,k,iBlock))
       x_D(y_) = 0.5*sum(y_Blk(0:1,j,k,iBlock))
       x_D(z_) = 0.5*sum(z_Blk(0:1,j,k,iBlock))

       call get_plasma_parameters_base(x_D, RhoBase, Tbase)

       if(TypeBc == 'usersemi')then
          StateSemi_VGB(iTeImpl,0,j,k,iBlock) = Tbase
       else
          ! Fixed density
          State_VGB(Rho_,-1:0,j,k,iBlock) = RhoBase

          ! fixed electron and ion temperature
          do i = -1, 0
             NumDensIon = State_VGB(Rho_,i,j,k,iBlock)/MassIon_I(1)
             NumDensElectron = NumDensIon*AverageIonCharge
             if(UseElectronPressure)then
                State_VGB(p_,i,j,k,iBlock) = NumDensIon*Tbase
                State_VGB(Pe_,i,j,k,iBlock) = NumDensElectron*Tbase
             else
                State_VGB(p_,i,j,k,iBlock) = &
                     (NumDensIon + NumDensElectron)*Tbase
             end if
          end do
       end if

    end do; end do

  end subroutine user_set_cell_boundary

  !============================================================================

  subroutine user_set_face_boundary(VarsGhostFace_V)

    use BATL_size,      ONLY: MinI, MaxI, MinJ, MaxJ, MinK, MaxK
    use ModAdvance,     ONLY: State_VGB, UseElectronPressure
    use ModFaceBoundary, ONLY: FaceCoords_D, VarsTrueFace_V, B0Face_D, &
         iSide, iFace, jFace, kFace, iBlockBc
    use ModMain,        ONLY: x_, y_, z_, UseRotatingFrame, &
         UseHeatConduction
    use ModMultiFluid,  ONLY: MassIon_I
    use ModPhysics,     ONLY: OmegaBody, AverageIonCharge
    use ModVarIndexes,  ONLY: nVar, Rho_, Ux_, Uy_, Uz_, Bx_, By_, Bz_, p_, &
         WaveFirst_, WaveLast_, Pe_

    real, intent(out) :: VarsGhostFace_V(nVar)

    real :: RhoBase, NumDensIon, NumDensElectron, Tbase, FullBr, B0tot
    real :: Runit_D(3), U_D(3)
    real :: B1_D(3), B1t_D(3), B1r_D(3), FullB_D(3), B0_D(3)
    real :: Ewave, HeatFlux
    !--------------------------------------------------------------------------

    Runit_D = FaceCoords_D/sqrt(sum(FaceCoords_D**2))

    U_D   = VarsTrueFace_V(Ux_:Uz_)
    VarsGhostFace_V(Ux_:Uz_) = -U_D

    B1_D  = VarsTrueFace_V(Bx_:Bz_)
    B1r_D = sum(Runit_D*B1_D)*Runit_D
    B1t_D = B1_D - B1r_D
    VarsGhostFace_V(Bx_:Bz_) = B1t_D !- B1r_D
    FullB_D = B0Face_D + B1t_D
    B0tot = sqrt(sum(B0Face_D**2))
    FullBr = sum(Runit_D*FullB_D)

    call get_plasma_parameters_base(FaceCoords_D, RhoBase, Tbase)

    VarsGhostFace_V(Rho_) =  2.0*RhoBase - VarsTrueFace_V(Rho_)
    NumDensIon = VarsGhostFace_V(Rho_)/MassIon_I(1)
    NumDensElectron = NumDensIon*AverageIonCharge
    if(UseElectronPressure)then
       VarsGhostFace_V(p_) = max(NumDensIon*Tbase, VarsTrueFace_V(p_))
       VarsGhostFace_V(Pe_) = NumDensElectron*Tbase
    else
       if(UseHeatConduction)then
          VarsGhostFace_V(p_) = (NumDensIon + NumDensElectron)*Tbase
       else
          VarsGhostFace_V(p_) = &
               max((NumDensIon + NumDensElectron)*Tbase, VarsTrueFace_V(p_))
       end if
    end if

    ! Contribution of the heat flux on Bernoulli equation
    HeatFlux = 0.0
    if(UseHeatFluxInBernoulli) call get_boundary_heatflux

    ! Set Alfven waves energy density
    call get_wave_energy(FaceCoords_D(x_), FaceCoords_D(y_), FaceCoords_D(z_),&
         FullBr, B0tot, HeatFlux, Ewave)

    if(FullBr > 0.0)then
       VarsGhostFace_V(WaveFirst_) = Ewave
       VarsGhostFace_V(WaveLast_) = VarsTrueFace_V(WaveLast_)
    else
       VarsGhostFace_V(WaveFirst_) = VarsTrueFace_V(WaveFirst_)
       VarsGhostFace_V(WaveLast_) = Ewave
    end if

    !\
    ! Apply corotation if needed
    !/
    if(.not.UseRotatingFrame)then
       VarsGhostFace_V(Ux_) = VarsGhostFace_V(Ux_) &
            - 2.0*OmegaBody*FaceCoords_D(y_)
       VarsGhostFace_V(Uy_) = VarsGhostFace_V(Uy_) &
            + 2.0*OmegaBody*FaceCoords_D(x_)
    end if

  contains

    subroutine get_boundary_heatflux

      use ModFaceGradient, ONLY: get_face_gradient

      real :: FaceGrad_D(3)
      integer :: iBlock, iDir, i, j, k
      !------------------------------------------------------------------------
      iBlock = iBlockBc

      if(iSide==1 .or. iSide==2)then
         iDir = x_
      elseif(iSide==3 .or. iSide==4)then
         iDir = y_
      else
         iDir = z_
      endif

      if(IsNewBlockTe_B(iBlock))then
         if(UseElectronPressure)then
            do k = MinK, MaxK; do j = MinJ, MaxJ; do i = MinI, MaxI
               Te_G(i,j,k) = TeFraction*State_VGB(Pe_,i,j,k,iBlock) &
                    /State_VGB(Rho_,i,j,k,iBlock)
            end do; end do; end do
         else
            do k = MinK, MaxK; do j = MinJ, MaxJ; do i = MinI, MaxI
               Te_G(i,j,k) = TeFraction*State_VGB(p_,i,j,k,iBlock) &
                    /State_VGB(Rho_,i,j,k,iBlock)
            end do; end do; end do
         end if
      end if

      call get_face_gradient(iDir, iFace, jFace, kFace, iBlock, &
           IsNewBlockTe_B(iBlock), Te_G, FaceGrad_D)

      ! Use 1D proxi for heat flux
      HeatFlux = -HeatCondPar*Tbase**2.5*sum(FaceGrad_D*Runit_D)

    end subroutine get_boundary_heatflux

  end subroutine user_set_face_boundary

  !============================================================================

  subroutine user_set_resistivity(iBlock, Eta_G)

    use ModAdvance,    ONLY: State_VGB
    use ModMain,       ONLY: nI, nJ, nK
    use ModPhysics,    ONLY: No2Si_V, Si2No_V, UnitTemperature_, UnitX_, UnitT_
    use ModVarIndexes, ONLY: Rho_, Pe_

    integer, intent(in) :: iBlock
    real,    intent(out):: Eta_G(-1:nI+2,-1:nJ+2,-1:nK+2)

    integer :: i, j, k
    real :: Te, TeSi

    character (len=*), parameter :: NameSub = 'user_set_resistivity'
    !--------------------------------------------------------------------------

    do k = -1, nK+2; do j = -1, nJ+2; do i = -1, nI+2
       Te = TeFraction*State_VGB(Pe_,i,j,k,iBlock)/State_VGB(Rho_,i,j,k,iBlock)
       TeSi = Te*No2Si_V(UnitTemperature_)

       Eta_G(i,j,k) = EtaPerpSi/TeSi**1.5 *Si2No_V(UnitX_)**2/Si2No_V(UnitT_)
    end do; end do; end do

  end subroutine user_set_resistivity

end module ModUser
