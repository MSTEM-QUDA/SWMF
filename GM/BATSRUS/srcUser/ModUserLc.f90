!^CFG COPYRIGHT UM
!==============================================================================
!Description (Sokolov, Feb.,04,2010)
!Coded by: Cooper Downs /cdowns@ifa.hawaii.edu (version 0)
!Development for the present version: Igor Sokolov
!read_inputs: #TRBOUNDARY (sets the type of BC at the corona boundary)
!Do not read TeBoundary and NeBoundary, set them equal to those
!for chromosphere or for the top of the transition region, depending on the BC
!
!init_session: checks the presence of #TRBOUNDARY, #MAGNETOGRAM and
!#PLASMA commands, sets the dimensionless constans for density and temperature
!at the coronal base and for the heat conduction coefficient.
!
!set_ics: initialize the MHD parameters using the Parker solution.
!Intialize waves acoordin to the "adiabatic law"
!
!
!set_initial_perturbation: initialize the "unsigned flux" model, calculate 
!the total heating and compares with the contribution from the primary model
!
!face_bcs: implements two sorts of the BC at the low boundary: chromo and REB
!Set the BC for waves
!
!get_log_var: magnetic and internal energy, total heating
!
!calc_sources: modify the time step to prevent the code instability at large
!values of the cooling function
!
!update_states: sets the logical at each used block needed for REB model
!
!specify refinement: refine a current sheet
!
!set_boundary_cells: to use the "extra" inner boundary
!
!set_outer_BC: set the boundary values for temperature as needed for the 
!parallel heat conduction
!
!set_plot_var: implement plot variables qheat and qrad (heating and cooling
!functions
! 
module ModUser
  use ModMain,      ONLY: nBLK, nI, nJ, nK
  use ModReadParam, ONLY: lStringLine
  use ModCoronalHeating,ONLY: CoronalHeating_C,get_cell_heating
  use ModRadiativeCooling
  use ModUserEmpty,                                     &
       IMPLEMENTED1 => user_read_inputs,                &
       IMPLEMENTED2 => user_init_session,               &
       IMPLEMENTED3 => user_set_ics,                    &
       IMPLEMENTED4 => user_initial_perturbation,       &
       IMPLEMENTED5 => user_set_face_boundary,                   &
       IMPLEMENTED6 => user_get_log_var,                &
       IMPLEMENTED7 => user_calc_sources,               &
       IMPLEMENTED8 => user_update_states,              &
       IMPLEMENTED9 => user_specify_refinement,         &
       IMPLEMENTED11=> user_set_cell_boundary,               &
       IMPLEMENTED12=> user_set_plot_var


  include 'user_module.h' !list of public methods

  real, parameter :: VersionUserModule = 1.0
  character (len=*), parameter :: &
       NameUserModule = 'Low Corona / Heating by waves'


  ! ratio of electron Temperature / Total Temperature
  ! given by the formula P = ne * k_B*Te + n_i k_B*T_i
  real :: TeFraction


  ! additional variables for TR boundary / heating models
  character(len=lStringLine) :: TypeTRBoundary

  logical :: DoChromoBC  = .false.
  logical :: DoCoronalBC = .false.
  logical :: DoREBModel  = .false.

  ! boundary condition variables to be read from PARAM.in
  real :: BoundaryTeSi = 1.5E+6
  real :: BoundaryNeCgs = 3.0E+8
  ! dimensionless values of boundary electron temp Te and mass density
  real :: BoundaryTe
  real :: BoundaryRho


  ! Variables for the REB model
  logical :: IsNewBlockTeCalc(nBLK) = .true.
  ! cell centered electron temperature for entire block
  ! put here so not always re-computed during boundary calculation
  real :: Te_G(MinI:MaxI,MinJ:MaxJ,MinK:MaxK) 

contains

  !============================================================================

  subroutine user_read_inputs

    use ModMain,        ONLY: lVerbose, UseUserInitSession     
    use ModProcMH,      ONLY: iProc
    use ModReadParam,   ONLY: read_line, read_command, read_var
    use ModIO,          ONLY: write_prefix, write_myname, iUnitOut
    use ModPhysics,     ONLY: SW_T_dim, SW_n_dim
   

    character (len=100) :: NameCommand
    character(len=*), parameter :: NameSub = 'user_read_inputs'
    !--------------------------------------------------------------------------
    UseUserInitSession = .true.
    UseRadCooling=.true.

    if(iProc == 0 .and. lVerbose > 0)then
       call write_prefix;
       write(iUnitOut,*)'User read_input SOLAR CORONA starts'
    endif

    do
       if(.not.read_line() ) EXIT
       if(.not.read_command(NameCommand)) CYCLE

       select case(NameCommand)

       case("#TRBOUNDARY")
          call read_var('TypeTRBoundary', TypeTRBoundary)
          call read_var('BoundaryNeCgs',BoundaryNeCgs)
          call read_var('BoundaryTeSi',BoundaryTeSi)
          select case(TypeTRBoundary)
          case('chromo')
             DoChromoBC  = .true.
             DoCoronalBC = .false.
             DoREBModel  = .false.
          case('coronal')
             DoChromoBC  = .false.
             DoCoronalBC = .true.
             DoREBModel  = .false.
          case('reb','REB')
             DoChromoBC  = .false.
             DoCoronalBC = .false.
             DoREBModel  = .true.
          case default
             call stop_mpi(NameSub//': unknown TypeTRBoundary = ' &
                  //TypeTRBoundary)
          end select

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

    use ModAdvance,     ONLY: WaveFirst_, WaveLast_
    use ModIO,          ONLY: write_prefix, iUnitOut,NamePlotDir
    use ModMagnetogram, ONLY: read_magnetogram_file
    use ModMultiFluid,  ONLY: MassIon_I
    use ModPhysics,     ONLY: Si2No_V, UnitP_, UnitEnergyDens_, UnitT_, &
         ElectronTemperatureRatio, AverageIonCharge, UnitTemperature_, &
         UnitRho_, No2Si_V, UnitN_, UnitU_, UnitX_
    use ModProcMH,      ONLY: iProc
    use ModReadParam,   ONLY: i_line_command
    use ModWaves
    use ModMain,        ONLY: optimize_message_pass, UseMagnetogram
    use ModConst,       ONLY: cBoltzmann, cElectronMass, cProtonMass, &
         cEps, cElectronCharge, cTwoPi

    real, parameter:: CoulombLog = 20.0

    !--------------------------------------------------------------------------
    if(iProc == 0)then
       call write_prefix; write(iUnitOut,*) ''
       call write_prefix; write(iUnitOut,*) 'user_init_session:'
       call write_prefix; write(iUnitOut,*) ''
    end if
    if(.not.UseMagnetogram)then
       if(i_line_command("#PFSSM", iSessionIn = 1) < 0)then
          write(*,*) 'In session 1, a magnetogram file has to be read via #PFSSM'
          call stop_mpi('ERROR: Correct PARAM.in!')
       end if
       if(i_line_command("#PFSSM") > 0)then
          call read_magnetogram_file(NamePlotDir)
       end if
    end if
    if(i_line_command("#TRBOUNDARY", iSessionIn = 1) < 0)then
       write(*,*) 'In session 1, need to specify a BC with #TRBOUNDARY!'
       call stop_mpi('ERROR: Correct PARAM.in!')
    end if

    if(optimize_message_pass/='all') then
       write(*,*) 'For Heat Conduction need message pass = all with ',&
            '#MESSAGEPASS!'
       call stop_mpi('ERROR: Correct PARAM.in!')
    end if

    if(i_line_command("#PLASMA", iSessionIn = 1) < 0)then
       write(*,*) 'Need to set electron temp ration with #PLASMA!'
       call stop_mpi('ERROR: Correct PARAM.in!')
    end if

    ! ratio of Te / (Te + Tp)
    ! given by the formula P = ne * k_B*Te + n_i k_B*T_i
    TeFraction = MassIon_I(1)*ElectronTemperatureRatio &
         /(1 + AverageIonCharge*ElectronTemperatureRatio)


    ! calc normalized values of BC Te and Ne
    ! note, implicitly assuming Ne = Ni here
    BoundaryTe = BoundaryTeSi * Si2No_V(UnitTemperature_)
    BoundaryRho = BoundaryNeCgs * 1.0E+6 * Si2No_V(UnitN_)

    if(iProc == 0)then
       if(UseRadCoolingTable) then
          call write_prefix;  write(iUnitOut,*) 'Using Tabulated RadCooling'
       else
          call write_prefix;  write(iUnitOut,*) 'Using Analytic Fit to ', &
                                 'RadCooling'
       end if
       call write_prefix; write(iUnitOut,*) ''

       if(DoExtendTransitionRegion)then
          call write_prefix;  write(iUnitOut,*) 'using Modified Heat Conduction'
          call write_prefix;  write(iUnitOut,*) 'TeModSi      = ', TeModSi
          call write_prefix;  write(iUnitOut,*) 'DeltaTeModSi = ', DeltaTeModSi
          call write_prefix;  write(iUnitOut,*) ''
       end if

       call write_prefix; write(iUnitOut,*) 'TeFraction = ',TeFraction
       call write_prefix; write(iUnitOut,*) ''
       call write_prefix; write(iUnitOut,*) 'user_init_session finished'
       call write_prefix; write(iUnitOut,*) ''
    end if

  end subroutine user_init_session

  !============================================================================

  subroutine user_set_face_boundary(VarsGhostFace_V)

    use ModAdvance,     ONLY: State_VGB, WaveFirst_, WaveLast_
    use ModFaceBoundary, ONLY: FaceCoords_D, VarsTrueFace_V, B0Face_D, &
         iSide, iFace, jFace, kFace, iBlockBc
    use ModMain,        ONLY: x_, y_, z_, UseRotatingFrame, nI, nJ, nK
    use ModNumConst,    ONLY: cTolerance
    use ModPhysics,     ONLY: OmegaBody, BodyRho_I, BodyTDim_I, &
         UnitTemperature_, Si2No_V, No2Si_V, UnitN_, UnitEnergyDens_, &
         UnitT_, UnitX_
    use ModVarIndexes,  ONLY: nVar, Rho_, Ux_, Uy_, Uz_, Bx_, By_, Bz_, p_
    use ModFaceGradient, ONLY: get_face_gradient
    use ModWaves,       ONLY: UseAlfvenWaves
    use ModAlfvenWaveHeating, ONLY: adiabatic_law_4_wave_state


    real, intent(out) :: VarsGhostFace_V(nVar)

    real :: Density, Temperature, FullBr
    real :: Runit_D(3), U_D(3)
    real :: B1_D(3), B1t_D(3), B1r_D(3), FullB_D(3)
    !--------------------------------------------------------------------------

    Runit_D = FaceCoords_D/sqrt(sum(FaceCoords_D**2))

    U_D   = VarsTrueFace_V(Ux_:Uz_)
    B1_D  = VarsTrueFace_V(Bx_:Bz_)
    B1r_D = dot_product(Runit_D, B1_D)*Runit_D
    B1t_D = B1_D - B1r_D

    VarsGhostFace_V(Ux_:Uz_) = -U_D
    VarsGhostFace_V(Bx_:Bz_) = B1t_D !- B1r_D

    FullB_D = B0Face_D + B1t_D
    FullBr = dot_product(Runit_D, FullB_D)



    Density = BoundaryRho
    if(DoREBModel) Density = calc_reb_density()

    Temperature = BoundaryTe/TeFraction


    VarsGhostFace_V(Rho_) =  Density
    VarsGhostFace_V(p_) = Density*Temperature
    if(UseAlfvenWaves)call adiabatic_law_4_wave_state(&
        VarsGhostFace_V, FaceCoords_D, B0Face_D)

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
    !==========================================================================
    real function calc_reb_density()
      use ModConst, ONLY: kappa_0_e

      ! function to return the density given by the Radiative Energy Balance Model
      ! (REB) for the Transition region. Originally given in Withbroe 1988, this
      ! uses eq from Lionell 2001. NO enthalpy flux correction in this
      ! implementation.

      real :: FaceGrad_D(3),GradTeSi_D(3)
      real :: TotalFaceB_D(3), TotalFaceBunit_D(3)

      ! Here Rad integral is integral of lossfunction*T^(1/2) from T=10,000 to
      ! 500,000. Use same approximate loss function used in BATS to calculate
      ! This is in SI units [J m^3 K^(3/2)]
      real :: RadIntegralSi = 1.009E-26

      ! Left and right cell centered heating
      real :: CoronalHeatingLeft, CoronalHeatingRight, CoronalHeating

      ! Condensed terms in the REB equation
      real :: qCondSi, qHeatSi

      integer :: iBlock, iDir=0

      !--------------------------------------------------------------------------

      iBlock = iBlockBc

      ! need to get direction for face gradient calc
      ! also put left cell centered heating call here (since index depends on
      ! the direction)
      if(iSide==1 .or. iSide==2) then 
         iDir = x_
         call get_cell_heating(iFace-1, jFace, kFace, iBlock, CoronalHeatingLeft)
      elseif(iSide==3 .or. iSide==4) then 
         iDir = y_
         call get_cell_heating(iFace, jFace-1, kFace, iBlock, CoronalHeatingLeft)
      elseif(iSide==5 .or. iSide==6) then
         iDir = z_
         call get_cell_heating(iFace, jFace, kFace-1, iBlock, CoronalHeatingLeft)
      else
         call stop_mpi('REB model got bad face direction')
      endif

      call get_cell_heating(iFace, jFace, kFace, iBlock, CoronalHeatingRight)

      CoronalHeating = 0.5 * (CoronalHeatingLeft + CoronalHeatingRight)

      ! term based on coronal heating into trans region (calc face centered avg)
      qHeatSi = (2.0/7.0) * CoronalHeating * BoundaryTeSi**1.5 &
                 * No2Si_V(UnitEnergyDens_) / No2Si_V(UnitT_)

      ! now calculate the contribution due to heat conduction into the boundary
      if(IsNewBlockTeCalc(iBlock)) Te_G = State_VGB(P_,:,:,:,iBlock) / &
           State_VGB(Rho_,:,:,:,iBlock) * TeFraction

      call get_face_gradient(iDir, iFace, jFace, kFace, iBlock, &
           IsNewBlockTeCalc(iBlock), Te_G, FaceGrad_D)

      ! calculate the unit vector of the total magnetic field
      TotalFaceB_D = B0Face_D + B1_D
      TotalFaceBunit_D = TotalFaceB_D / sqrt(sum(TotalFaceB_D**2))

      ! calculate the heat conduction term in the REB numerator
      qCondSi = 0.5 * kappa_0_e(20.) * BoundaryTeSi**3 &
           * sum(FaceGrad_D*TotalFaceBunit_D)**2 &
           * (No2Si_V(UnitTemperature_) / No2Si_V(UnitX_))**2

      ! put the terms together and calculate the REB density
      calc_reb_density = sqrt((qCondSi + qHeatSi) / RadIntegralSi) &
           * Si2No_V(UnitN_)

    end function calc_reb_density


  end subroutine user_set_face_boundary

  !============================================================================

  subroutine user_set_ics(iBlock)

    use ModAdvance,    ONLY: State_VGB, WaveFirst_, WaveLast_, B0_DGB
    use ModGeometry,   ONLY: Xyz_DGB, r_Blk, true_cell
    use ModMain,       ONLY: nI, nJ, nK
    use ModPhysics,    ONLY: Si2No_V, UnitTemperature_, rBody, GBody, &
         BodyRho_I, BodyTDim_I, No2Si_V, UnitU_, UnitN_
    use ModVarIndexes, ONLY: Rho_, RhoUx_, RhoUy_, RhoUz_, Bx_, Bz_, p_
    use ModWaves,       ONLY: UseAlfvenWaves
    use ModAlfvenWaveHeating, ONLY: adiabatic_law_4_wave_state

    integer, intent(in) :: iBlock

    integer :: i, j, k

    ! Variables for IC using Parker Isothermal Wind Solution
    ! Parker part copied from ModUserScHeat.f90 on 9/20/2009
    integer :: IterCount
    real :: x, y, z, r, RhoBase, Tbase, Rho, rBase
    real :: Ur, Ur0, Ur1, del, Ubase, rTransonic, Uescape, Usound, T0
    real, parameter :: Epsilon = 1.0e-6

    ! variables for adding in TR like icond if needed
    ! this is from 2 lines that piecewise fit an old relaxed solution
    ! not really physical! just gets you close
    ! also, if solutions change significantly, will need to update
    real, parameter :: rTransRegion = 1.03       ! widened w/ modify heatflux approximation
    real, parameter :: PowerTe = 341.81783
    real, parameter :: PowerNe = -745.56192
    real, parameter :: NeEmpirical = 6.0E+8
    real, parameter :: TeEmpirical = 6.0E+5
    real, parameter :: rEmpirical = 1.01
    ! TeBaseCGS and NeBaseCGS and rBase are values that match the coronal
    ! Solution at rTransRegion
    real :: TeBaseCgs, NeBaseCgs, NeValue, TeValue

    !--------------------------------------------------------------------------
    ! This icond implements the radially symmetric parker isothermal wind solution 
    ! for the corona. If using a chromospheric condition, extend base of wind solution
    ! to r=rTransRegion, and put in approximate transition region below 
    ! 
    ! NOTE this coronal icond does NOT use T value from the PARAM.in
    ! #BODY command, instead it sets the coronal Te to 1.5 MK everywhere.
    ! It DOES however, set the base density of the coronal part according to 
    ! BodyRho_I(1)

    T0 = 3.0e6*Si2No_V(UnitTemperature_)
    rBase = rBody
    RhoBase = rBase**2 * BodyRho_I(1)
    NeBaseCGS = RhoBase * No2Si_V(UnitN_) * 1.0E-6
    TeBaseCGS = TeFraction * T0 * No2Si_V(UnitTemperature_)

    Usound = sqrt(T0)
    Uescape = sqrt(-GBody*2.0/rBase)/Usound

    !\
    ! Initialize MHD wind with Parker's solution
    ! construct solution which obeys
    !   rho x u_r x r^2 = constant
    !/
    rTransonic = 0.25*Uescape**2
    if(.not.(rTransonic>exp(1.0))) call stop_mpi('sonic point inside Sun')

    Ubase = rTransonic**2*exp(1.5 - 2.0*rTransonic)

    do k = 1, nK; do j = 1, nJ; do i = 1, nI
       x = Xyz_DGB(x_,i,j,k,iBlock)
       y = Xyz_DGB(y_,i,j,k,iBlock)
       z = Xyz_DGB(z_,i,j,k,iBlock)
       r = max(r_BLK(i,j,k,iBlock),1.0)
       if(.not.true_cell(i,j,k,iBlock)) CYCLE

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

       Rho = RhoBase*Ubase/(r**2*Ur)
       State_VGB(Rho_,i,j,k,iBlock) = Rho
       State_VGB(RhoUx_,i,j,k,iBlock) = Rho*Ur*x/r *Usound
       State_VGB(RhoUy_,i,j,k,iBlock) = Rho*Ur*y/r *Usound
       State_VGB(RhoUz_,i,j,k,iBlock) = Rho*Ur*z/r *Usound
       State_VGB(P_,i,j,k,iBlock) = Rho*T0
       State_VGB(Bx_:Bz_,i,j,k,iBlock) = 0.0
       if(UseAlfvenWaves)call adiabatic_law_4_wave_state(&
            State_VGB(:, i, j, k, iBlock),&
            (/Xyz_DGB(x_,i, j, k, iBlock), &
              Xyz_DGB(y_,i, j, k, iBlock), &
              Xyz_DGB(z_,i, j, k, iBlock)/), &
              B0_DGB(:, i, j, k, iBlock))
    end do; end do; end do

  end subroutine user_set_ics

  !============================================================================

  subroutine user_initial_perturbation
    use ModMain, ONLY: nI ,nJ , nK, nBLK, Unused_B, x_, y_, z_
    use ModProcMH,    ONLY: iProc, iComm
    use ModPhysics,   ONLY: No2Si_V, UnitX_, UnitEnergyDens_, UnitT_, rBody
    use ModCoronalHeating, ONLY: TotalCoronalHeatingCgs, &
         UseUnsignedFluxModel, get_coronal_heat_factor
    use ModProcMH,      ONLY: iProc
    use ModIO,          ONLY: write_prefix, iUnitOut
    use ModMpi
    use ModCoronalHeating,ONLY:UseExponentialHeating,&
         DecayLengthExp,HeatingAmplitudeCGS,WSAT0,DoOpenClosedHeat
    use ModRadiativeCooling
    use BATL_lib, ONLY: CellVolume_GB

    integer :: i, j, k, iBlock, iError
    logical :: oktest, oktest_me

    real :: TotalHeatingProc, TotalHeating, TotalHeatingCgs, CoronalHeating
    real :: TotalHeatingModel = 0.0
    !--------------------------------------------------------------------------
    call set_oktest('user_initial_perturbation',oktest,oktest_me)

    ! Calculate the total power into the Computational Domain, loop over
    ! every cell, add the heating, and after block loop, MPI_reduce

    ! Do this because want to be able to generalize models, which can depend on 
    ! topology of domain --> total heating not always known beforehand 

    ! Need to initialize unsigned flux model first

    !write(*,*)'Radiation cooling integral equals:',cooling_function_integral_si(5.0e5)
    if(UseUnsignedFluxModel) call get_coronal_heat_factor

    TotalHeatingProc = 0.0


    do iBlock=1,nBLK
       if(Unused_B(iBlock))CYCLE
       do k=1,nK; do j=1,nJ; do i=1,nI

          ! Calc heating (Energy/Volume/Time) for the cell 
          call get_cell_heating(i, j, k, iBlock, CoronalHeating)

          ! Multiply by cell volume and add to sum
          TotalHeatingProc = TotalHeatingProc + CoronalHeating &
               *CellVolume_GB(i,j,k,iBlock)

       end do; end do; end do

    end do

    ! now collect sum over procs
    call MPI_allreduce(TotalHeatingProc, TotalHeating, 1, &
         MPI_REAL, MPI_SUM, iComm, iError)

    ! Convert total into CGS units
    TotalHeatingCgs = TotalHeating * No2Si_V(UnitEnergyDens_) * 10.0 &
         / No2Si_V(UnitT_) * (No2Si_V(UnitX_) * 100.0)**3

    ! now compute the total heating of the main models alone
    ! if it were applied to entire domain (to check consistency)
    if(UseUnsignedFluxModel) TotalHeatingModel = TotalCoronalHeatingCgs

    if(UseExponentialHeating) then
       TotalHeatingModel = HeatingAmplitudeCgs * 4.0 * 3.1415927 &
            * (DecayLengthExp*rBody**2 + 2.0*DecayLengthExp**2 * rBody &
            + 2.0*DecayLengthExp**3) * (No2Si_V(UnitX_)*100.0)**3
    end if

    if(iProc==0) then
       call write_prefix; write(iUnitOut,*) ''
       call write_prefix; write(iUnitOut,*) '----- START Coronal Heating #s -----------'
       call write_prefix; write(iUnitOut,*) ''
       call write_prefix; write(iUnitOut,*) 'Total Heat of uniform single model'&
            //' (ergs / s) = ', TotalHeatingModel
       call write_prefix; write(iUnitOut,*) ''
       call write_prefix; write(iUnitOut,*) 'Total Heat into corona (ergs / s) = ',&
            TotalHeatingCgs
       call write_prefix; write(iUnitOut,*) ''
       call write_prefix; write(iUnitOut,*) '------- END Coronal Heating #s -----------'
       call write_prefix; write(iUnitOut,*) ''
       write(*,*) ''
    end if

  end subroutine user_initial_perturbation
  !============================================================================

  subroutine user_calc_sources(iBlock)

    use ModAdvance,        ONLY: State_VGB, Source_VC, Rho_, p_, Energy_, &
         VdtFace_x, VdtFace_y, VdtFace_z
    use ModGeometry,       ONLY: r_BLK
    use ModMain,           ONLY: nI, nJ, nK
    use ModPhysics,        ONLY: Si2No_V, UnitEnergyDens_, UnitTemperature_, &
         inv_gm1
    use BATL_lib, ONLY: CellVolume_GB

    integer, intent(in) :: iBlock

    integer :: i, j, k

    ! variables for checking timestep control
    logical, parameter :: DoCalcTime = .true.
    real :: TimeInvRad, TimeInvHeat, Einternal, Vdt_MaxSource

    character (len=*), parameter :: NameSub = 'user_calc_sources'
    !--------------------------------------------------------------------------

    ! Add this in for tentative timestep control from large source terms
    ! need this because radiative loss term becomes INSANELY large at
    ! Chromospheric densities

    if(.not.DoCalcTime)return

    do k = 1, nK; do j = 1, nJ; do i = 1, nI
       Einternal = inv_gm1 * State_VGB(P_,i,j,k,iBlock)
       TimeInvRad  = abs(RadCooling_c(i,j,k)/ Einternal)
       TimeInvHeat = abs(CoronalHeating_C(i,j,k)   / Einternal)

       Vdt_MaxSource = (TimeInvRad + TimeInvHeat)*CellVolume_GB(i,j,k,iBlock)

       !**** NOTE This Is a CELL CENTERED TIMESCALE since sources are cell
       ! centered. For now, add to lefthand VdtFace, knowing that calc timestep 
       ! looks at MAX of VdtFaces on all sides
       ! (however cells at the edge of the block will only see one neighbor...) 
       VdtFace_x(i,j,k) = VdtFace_x(i,j,k) + 2.0 * Vdt_maxsource
       VdtFace_y(i,j,k) = VdtFace_y(i,j,k) + 2.0 * Vdt_maxsource
       VdtFace_z(i,j,k) = VdtFace_z(i,j,k) + 2.0 * Vdt_maxsource


    end do; end do; end do

  end subroutine user_calc_sources
  !============================================================================

  subroutine user_update_states(iStage, iBlock)

    integer, intent(in) :: iStage, iBlock
    !--------------------------------------------------------------------------
    
    call update_states_MHD(iStage, iBlock)
    
    ! REB model calls face gradient calculation, reset block logical
    ! so that the Te block will be re-calculated next pass
    if(DoREBModel) IsNewBlockTeCalc(iBlock) = .true.
    
  end subroutine user_update_states
  
  !============================================================================
  
  subroutine user_get_log_var(VarValue,TypeVar,Radius)
    
    use ModIO,         ONLY: write_myname
    use ModMain,       ONLY: Unused_B, nBlock, x_, y_, z_
    use ModVarIndexes, ONLY: Bx_, By_, Bz_, p_ 
    use ModAdvance,    ONLY: State_VGB, tmp1_BLK, B0_DGB
    use ModPhysics,    ONLY: inv_gm1, No2Io_V, UnitEnergydens_, UnitX_, &
         UnitT_, No2Si_V
    use ModCoronalHeating, ONLY: HeatFactor,HeatNormalization
    use ModProcMH,     ONLY: nProc
    
    real, intent(out) :: VarValue
    character (LEN=10), intent(in) :: TypeVar 
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
          tmp1_BLK(:,:,:,iBlock) = State_VGB(P_,:,:,:,iBlock)
       end do
       VarValue = unit_energy*inv_gm1*integrate_BLK(1,tmp1_BLK)
       
    case('emag')
       do iBlock = 1, nBlock
          if(Unused_B(iBlock)) CYCLE
          tmp1_BLK(:,:,:,iBlock) = & 
               ( B0_DGB(x_,:,:,:,iBlock) + State_VGB(Bx_,:,:,:,iBlock))**2 &
               +(B0_DGB(y_,:,:,:,iBlock) + State_VGB(By_,:,:,:,iBlock))**2 &
               +(B0_DGB(z_,:,:,:,iBlock) + State_VGB(Bz_,:,:,:,iBlock))**2
       end do
       VarValue = unit_energy*0.5*integrate_BLK(1,tmp1_BLK)
       
    case('vol')
       tmp1_BLK(:,:,:,iBlock) = 1.0
       VarValue = integrate_BLK(1,tmp1_BLK)
       
    case('psi')
       VarValue = HeatFactor * No2Si_V(UnitEnergyDens_) / No2Si_V(UnitT_) &
            * 10.0 / nProc * HeatNormalization
       
    case default
       VarValue = -7777.
       call write_myname;
       write(*,*) 'Warning in set_user_logvar: unknown logvarname = ',TypeVar
    end select
    
  end subroutine user_get_log_var
  
  !============================================================================
  
  subroutine user_specify_refinement(iBlock, iArea, DoRefine)


    integer, intent(in) :: iBlock, iArea
    logical,intent(out) :: DoRefine

    write(*,*)"#AMRCRITERIARESOLUTION"
    write(*,*)"1                       nCriteria "
    write(*,*)"currentsheet            TypeCriteria"
    write(*,*)"0.5                     CoarsenLimit"
    write(*,*)"0.5                     RefineLimit"
    write(*,*)"0.2                     MinResolution"
    write(*,*) ""
    write(*,*) "or"
    write(*,*) ""
    write(*,*)"#AMRCRITERIALEVEL"
    write(*,*)"1                       nCriteria"
    write(*,*)"currentsheet            TypeCriteria"
    write(*,*)"0.5                     CoarsenLimit"
    write(*,*)"0.5                     RefineLimit"
    write(*,*)"5                       MaxLevel"
    write(*,*) ""
    write(*,*) "and set right number of criteria and level/resolution."

    call stop_mpi('ERROR::  use aboue option in PARAM.in')

  end subroutine user_specify_refinement
  
  !============================================================================
  
  subroutine user_set_cell_boundary(iBlock,iSide, TypeBc, IsFound)
    
    use ModAdvance,  ONLY: Rho_, P_, State_VGB
    use ModGeometry, ONLY: TypeGeometry
    
    integer,          intent(in)  :: iBlock, iSide
    character(len=20),intent(in)  :: TypeBc
    logical,          intent(out) :: IsFound
    
    character (len=*), parameter :: NameSub = 'user_set_cell_boundary'
    !-------------------------------------------------------------------
    
    ! This routine used only for setting the inner r ghost cells for
    ! spherical geometry. Need to fix the temperature to the boundary
    ! temperature (which is NOT necessarily the BODY normalization values)
    ! for the heat conduction calculation. The face_gradient calculation
    ! uses ghost cells! If face gradient was checking values other than
    ! P/rho, would need to set those as well!
    
    if(iSide==1) then
       State_VGB(Rho_,-1:0,:,:,iBlock) = BoundaryRho
       State_VGB(P_  ,-1:0,:,:,iBlock) = BoundaryRho * BoundaryTe/TeFraction
    else
       call stop_mpi('For TR Model ONLY 1 (low R) user boundary can be used')
    endif
    
    IsFound = .true.
  end subroutine user_set_cell_boundary
  
  !===========================================================================
  subroutine user_set_plot_var(iBlock, NameVar, IsDimensional, &
       PlotVar_G, PlotVarBody, UsePlotVarBody, &
       NameTecVar, NameTecUnit, NameIdlUnit, IsFound)
    
    use ModSize,    ONLY: nI, nJ, nK
    use ModPhysics, ONLY: No2Si_V, UnitT_, UnitEnergyDens_, &
         UnitTemperature_
    use ModAdvance,  ONLY: State_VGB, Rho_, p_
    
    
    integer,          intent(in)   :: iBlock
    character(len=*), intent(in)   :: NameVar
    logical,          intent(in)   :: IsDimensional
    real,             intent(out)  :: PlotVar_G(MinI:MaxI, MinJ:MaxJ, MinK:MaxK)
    real,             intent(out)  :: PlotVarBody
    logical,          intent(out)  :: UsePlotVarBody
    character(len=*), intent(inout):: NameTecVar
    character(len=*), intent(inout):: NameTecUnit
    character(len=*), intent(inout):: NameIdlUnit
    logical,          intent(out)  :: IsFound
    
    character (len=*), parameter :: NameSub = 'user_set_plot_var'
    real                         :: UnitEnergyDensPerTime, CoronalHeating
    real                         :: RadiativeCooling
    integer                      :: i, j, k
    !-------------------------------------------------------------------    
    !UsePlotVarBody = .true. 
    !PlotVarBody = 0.0 
    IsFound=.true.
    
    UnitEnergyDensPerTime = 10.0 * No2Si_V(UnitEnergydens_) / No2Si_V(UnitT_)
    !\                                                                              
    ! Define plot variable to be saved::
    !/ 
    !
    select case(NameVar)
       !Allways use lower case !!
       
    case('qheat')
       do k=MinK,MaxK ; do j=MinJ,MaxJ ; do i=MinI,MaxI
          call get_cell_heating(i, j, k, iBlock, CoronalHeating)
          PlotVar_G(i,j,k) = CoronalHeating
       end do; end do ; end do
       PlotVar_G= PlotVar_G * UnitEnergyDensPerTime
       NameTecVar = 'qH'
       NameTecUnit = '[erg/cm^3/s]'
       NameIdlUnit = '[erg/cm^3/s]'
       
    case('qrad')
       do k=MinK,MaxK ; do j=MinJ,MaxJ ; do i=MinI,MaxI
          AuxTeSi = TeFraction * State_VGB(P_,i,j,k,iBlock) &
            / State_VGB(Rho_,i,j,k,iBlock) *No2Si_V(UnitTemperature_)

          call get_radiative_cooling(i, j, k, iBlock, AuxTeSi, RadiativeCooling)
          PlotVar_G(i,j,k) = RadiativeCooling
       end do; end do ; end do
       PlotVar_G= PlotVar_G * UnitEnergyDensPerTime
       NameTecVar = 'qR'
       NameTecUnit = '[erg/cm^3/s]'
       NameIdlUnit = '[erg/cm^3/s]'
       
    case default
       IsFound= .false.
    end select
  end subroutine user_set_plot_var
  
  !============================================================================ 
end module ModUser

