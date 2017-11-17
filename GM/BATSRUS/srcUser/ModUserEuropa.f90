!  Copyright (C) 2002 Regents of the University of Michigan,
!  portions used with permission
!  For more information, see http://csem.engin.umich.edu/tools/swmf
module ModUser

  use BATL_lib, ONLY: &
       test_start, test_stop, iTest, jTest, kTest, iBlockTest

  use ModSize
  use ModUserEmpty,                        &
       IMPLEMENTED1 => user_set_ics,       &
       IMPLEMENTED2 => user_read_inputs,   &
       IMPLEMENTED3 => user_calc_sources,  &
       IMPLEMENTED4 => user_update_states, &
       IMPLEMENTED5 => user_set_face_boundary

  include 'user_module.h' ! list of public methods

  real,              parameter :: VersionUserModule = 0.9
  character (len=*), parameter :: NameUserModule = &
       'Rubin single species Europa MHD module, Jun 2010'

  real, public, dimension(1:nI, 1:nJ, 1:nK, MaxBlock) :: Neutral_BLK
  real :: n0, dn, H, v, alpha, mi_mean, kin, distr
  real :: vNorm, alphaNorm, kinNorm, nNorm

contains
  !============================================================================

  subroutine user_read_inputs

    use ModMain
    use ModProcMH,    ONLY: iProc
    use ModReadParam
    use ModIO,        ONLY: write_prefix, write_myname, iUnitOut

    character (len=100) :: NameCommand

    logical:: DoTest
    character(len=*), parameter:: NameSub = 'user_read_inputs'
    !--------------------------------------------------------------------------
    call test_start(NameSub, DoTest)
    if(iProc==0.and.lVerbose > 0)then
       call write_prefix; write(iUnitOut,*)'User read_input Europa starts'
    endif

    do
       if(.not.read_line() ) EXIT
       if(.not.read_command(NameCommand)) CYCLE
       select case(NameCommand)

         case("#EUROPA")
            call read_var('n0' , n0)           !! Median neutral surface density [1/cm^3]
            call read_var('distr' , distr)     !! Ram side neutral distr: uniform (0) or cos (1)
            call read_var('dn' , dn)           !! Ram side fraction [%] only if distr==0
            call read_var('H' , H)             !! Neutral scale height [km]
            call read_var('v' , v)             !! Ionization rate [1/s]
            call read_var('alpha' , alpha)     !! Recombination rate [cm^3/s]
            call read_var('kin' , kin)         !! ion neutral friction [cm^3/s]
            call read_var('mi_mean' , mi_mean) !! mean ion mass [amu]
            H=H*1E3                            !! conversion to SI
            n0=n0*1E6                          !! conversion to SI
            dn=dn/100.0
         case('#USERINPUTEND')
            if(iProc==0.and.lVerbose > 0)then
               call write_prefix;
             write(iUnitOut,*)'User read_input EUROPA ends'
          endif
          EXIT
      case default
         if(iProc==0) then
            call write_myname; write(*,*) &
                  'ERROR: Invalid user defined #COMMAND in user_read_inputs. '
            write(*,*) '--Check user_read_inputs for errors'
            write(*,*) '--Check to make sure a #USERINPUTEND command was used'
            write(*,*) '  *Unrecognized command was: '//NameCommand
             call stop_mpi('ERROR: Correct PARAM.in or user_read_inputs!')
          end if
       end select
    end do

    call test_stop(NameSub, DoTest)
  end subroutine user_read_inputs
  !============================================================================

  subroutine user_set_ICs(iBlock)

    use ModPhysics
    use ModNumConst
    use ModGeometry, ONLY: R_BLK, Xyz_DGB

    integer, intent(in) :: iBlock

    integer :: i,j,k
    real :: theta

    ! neutral density in SI units
    logical:: DoTest
    character(len=*), parameter:: NameSub = 'user_set_ICs'
    !--------------------------------------------------------------------------
    call test_start(NameSub, DoTest, iBlock)
    do k=1,nK; do j=1,nJ; do i=1,nI
       ! angle of cell position relative to ram direction
       theta=acos((-SW_Ux*Xyz_DGB(x_,i,j,k,iBlock)-SW_Uy*Xyz_DGB(y_,i,j,k,iBlock)&
            -SW_Uz*Xyz_DGB(z_,i,j,k,iBlock))/R_BLK(i,j,k,iBlock)/&
            (SW_Ux**2+SW_Uy**2+SW_Uz**2)**0.5)

       if(distr==0) then
          ! uniform neutral density distribution
          if(theta<=cPi/2) then
             ! ram side
             Neutral_BLK(i,j,k,iBlock) = 2*dn*n0*exp(-(R_BLK(i,j,k,iBlock) - Rbody)&
                  /(H/rPlanetSi))
          else
             ! wake side
             Neutral_BLK(i,j,k,iBlock) = 2*(1-dn)*n0*exp(-(R_BLK(i,j,k,iBlock) - Rbody)&
                  /(H/rPlanetSi))
          end if
       else if(distr==1) then
          ! cosine neutral density distribution
          if(theta<=cPi/2) then
             ! ram side (100%), normalization factor 1/4
             Neutral_BLK(i,j,k,iBlock) = 4*cos(theta)*n0*exp(-(R_BLK(i,j,k,iBlock)&
                  - Rbody)/(H/rPlanetSi))
          else
             ! wake side is set to 0
             Neutral_BLK(i,j,k,iBlock) = 0
          end if
       end if

       if(iBlock==iBlockTest.and.k==kTest.and.j==jTest.and.i==iTest) then
          write(*,*)'X= ',Xyz_DGB(x_,i,j,k,iBlock),'Y= ',Xyz_DGB(y_,i,j,k,iBlock),&
               'Z= ',Xyz_DGB(z_,i,j,k,iBlock)
          write(*,*)'SW_Ux= ',SW_Ux,'SW_Uy= ',SW_Uy,'SW_Uz= ',SW_Uz
          write(*,*)'theta= ',theta,'n= ',Neutral_BLK(i,j,k,iBlock)
       end if
    end do;  end do;  end do

    vNorm=1/Si2No_V(UnitT_)                           !! conversion to unitless
    alphaNorm=1E-6/Si2No_V(UnitN_)/Si2No_V(UnitT_)    !! conversion to SI to unitless
    kinNorm=1E-6/Si2No_V(UnitN_)/Si2No_V(UnitT_)      !! conversion to SI to unitless
    nNorm=Si2No_V(UnitN_)                             !! conversion to unitless

    call test_stop(NameSub, DoTest, iBlock)
  end subroutine user_set_ICs
  !============================================================================

  subroutine user_calc_sources(iBlock)

    use ModMain,    ONLY: nI, nJ, nK
    use ModAdvance, ONLY: State_VGB, Source_VC, &
         Rho_, RhoUx_, RhoUy_, RhoUz_, Bx_,By_,Bz_, p_, Energy_
    use ModGeometry, ONLY: Xyz_DGB,R_BLK
    use ModPhysics
    use ModProcMH

    integer, intent(in) :: iBlock

    real, dimension(1:nI,1:nJ,1:nK) :: ux, uy, uz, uxyz, ne !!, Te
    real, dimension(1:nI,1:nJ,1:nK) :: Srho,SrhoUx,SrhoUy,SrhoUz,SBx,SBy,SBz,Sp,SE

    integer :: i,j,k

    logical:: DoTest
    character(len=*), parameter:: NameSub = 'user_calc_sources'
    !--------------------------------------------------------------------------
    call test_start(NameSub, DoTest, iBlock)
    ux=State_VGB(rhoUx_,1:nI,1:nJ,1:nK,iBlock) / &
          State_VGB(rho_,1:nI,1:nJ,1:nK,iBlock)
    uy=State_VGB(rhoUy_,1:nI,1:nJ,1:nK,iBlock) / &
          State_VGB(rho_,1:nI,1:nJ,1:nK,iBlock)
    uz=State_VGB(rhoUz_,1:nI,1:nJ,1:nK,iBlock) / &
          State_VGB(rho_,1:nI,1:nJ,1:nK,iBlock)

    uxyz = ux*ux+uy*uy+uz*uz

    ! ne is the electron density in SI units
    ne = State_VGB(rho_,1:nI,1:nJ,1:nK,iBlock)*No2SI_V(UnitN_)/mi_mean

    ! Electron temperature calculated from pressure assuming Te=Ti to calculate a more
    ! appropriate ion-electron recombination rate. p=nkT with n=ne+ni and ne=ni (quasi-neutrality)
    ! Te=State_VGB(p_,1:nI,1:nJ,1:nK,iBlock) * NO2SI_V(UnitP_) * mi_mean * cProtonMass / &
    !     ( 2.0 * NO2SI_V(UnitRho_) * cBoltzmann * State_VGB(rho_,1:nI,1:nJ,1:nK,iBlock) )

    ! Set the source arrays for this block to zero
    Srho   = 0.0
    SrhoUx = 0.0
    SrhoUy = 0.0
    SrhoUz = 0.0
    SBx    = 0.0
    SBy    = 0.0
    SBz    = 0.0
    SP     = 0.0
    SE     = 0.0

    do k=1,nK; do j=1,nJ; do i=1,nI
       Srho(i,j,k) = Neutral_BLK(i,j,k,iBlock)*nNorm*mi_mean*v*vNorm &   !! newly ionized neutrals
            - alpha*alphaNorm*State_VGB(rho_,i,j,k,iBlock)*ne(i,j,k)*Si2No_V(UnitN_) !! loss due to recombination

       SrhoUx(i,j,k) = - State_VGB(rho_,i,j,k,iBlock)*( &
            Neutral_BLK(i,j,k,iBlock)*nNorm*kin*kinNorm  &               !! loss due to charge exchange
            + alpha*alphaNorm*ne(i,j,k)*Si2No_V(UnitN_))*ux(i,j,k)          !! loss due to recombination

       SrhoUy(i,j,k) = - State_VGB(rho_,i,j,k,iBlock)*( &
            Neutral_BLK(i,j,k,iBlock)*nNorm*kin*kinNorm  &               !! loss due to charge exchange
            + alpha*alphaNorm*ne(i,j,k)*Si2No_V(UnitN_))*uy(i,j,k)          !! loss due to recombination

       SrhoUz(i,j,k) = - State_VGB(rho_,i,j,k,iBlock)*( &
            Neutral_BLK(i,j,k,iBlock)*nNorm*kin*kinNorm  &               !! loss due to charge exchange
            + alpha*alphaNorm*ne(i,j,k)*Si2No_V(UnitN_))*uz(i,j,k)          !! loss due to recombination

       SP(i,j,k) = 1/3*(v*vNorm*mi_mean + kin*kinNorm*State_VGB(rho_,i,j,k,iBlock))* &
            Neutral_BLK(i,j,k,iBlock)*nNorm*uxyz(i,j,k)  &               !! newly generated ions
            - State_VGB(p_,i,j,k,iBlock)*kin *kinNorm* &
            Neutral_BLK(i,j,k,iBlock)*nNorm &                            !! loss due to charge exchange
            - State_VGB(p_,i,j,k,iBlock)*alpha*alphaNorm*ne(i,j,k)*Si2No_V(UnitN_) !! loss due to recombination

       SE(i,j,k) = - 0.5*State_VGB(rho_,i,j,k,iBlock)*( &
            kin*kinNorm*Neutral_BLK(i,j,k,iBlock)*nNorm &                !! loss due to charge exchange
            + alpha *alphaNorm*ne(i,j,k)*Si2No_V(UnitN_))*uxyz(i,j,k) &     !! loss due to recombination
            - InvGammaMinus1*(kin*kinNorm - alpha *alphaNorm)*State_VGB(p_,i,j,k,iBlock)
    end do;  end do;  end do

    Source_VC(rho_   ,:,:,:) = Srho   + Source_VC(rho_   ,:,:,:)
    Source_VC(rhoUx_ ,:,:,:) = SrhoUx + Source_VC(rhoUx_ ,:,:,:)
    Source_VC(rhoUy_ ,:,:,:) = SrhoUy + Source_VC(rhoUy_ ,:,:,:)
    Source_VC(rhoUz_ ,:,:,:) = SrhoUz + Source_VC(rhoUz_ ,:,:,:)
    Source_VC(Bx_    ,:,:,:) = SBx    + Source_VC(Bx_    ,:,:,:)
    Source_VC(By_    ,:,:,:) = SBy    + Source_VC(By_    ,:,:,:)
    Source_VC(Bz_    ,:,:,:) = SBz    + Source_VC(Bz_    ,:,:,:)
    Source_VC(P_     ,:,:,:) = SP     + Source_VC(P_     ,:,:,:)
    Source_VC(Energy_,:,:,:) = SE     + Source_VC(Energy_,:,:,:)

    call test_stop(NameSub, DoTest, iBlock)
  end subroutine user_calc_sources
  !============================================================================

  subroutine user_update_states(iBlock)

    use ModUpdateState, ONLY: update_state_normal
    use ModVarIndexes
    use ModSize
    use ModAdvance, ONLY: State_VGB
    use ModPhysics
    use ModEnergy
    integer,intent(in):: iBlock
    integer:: i,j,k

    real :: Tmin = 50.0 !! Minimum ion temperature (Europa's nightside surface temperature)

    logical:: DoTest
    character(len=*), parameter:: NameSub = 'user_update_states'
    !--------------------------------------------------------------------------
    call test_start(NameSub, DoTest, iBlock)
    call update_state_normal(iBlock)

    ! Force minimum temperature:
    ! If the temperature is less than the prescribed minimum 'Tmin',
    ! set it to Tmin.

    where( State_VGB(p_,1:nI,1:nJ,1:nK,iBlock)*NO2SI_V(UnitP_) < &
           (State_VGB(rho_,1:nI,1:nJ,1:nK,iBlock)*NO2SI_V(UnitN_)/mi_mean)*cBoltzmann*Tmin )
       State_VGB(p_,1:nI,1:nJ,1:nK,iBlock) = &
           (State_VGB(rho_,1:nI,1:nJ,1:nK,iBlock)*NO2SI_V(UnitN_)/mi_mean)*cBoltzmann*Tmin/NO2SI_V(UnitP_)
    end where

    call calc_energy_cell(iBlock)

    call test_stop(NameSub, DoTest, iBlock)
  end subroutine user_update_states
  !============================================================================

  subroutine user_set_face_boundary(VarsGhostFace_V)

    use ModSize,       ONLY: nDim,2,4,6
    use ModVarIndexes
    use ModPhysics,    ONLY: SW_rho, SW_p, SW_T_dim, BodyNDim_I
    use ModFaceBoundary, ONLY: FaceCoords_D, VarsTrueFace_V

    real, intent(out):: VarsGhostFace_V(nVar)

    real:: UdotR, URefl_D(1:3)
    logical:: DoTest
    character(len=*), parameter:: NameSub = 'user_set_face_boundary'
    !--------------------------------------------------------------------------
    call test_start(NameSub, DoTest)
    UdotR = dot_product(VarsTrueFace_V(Ux_:Uz_),FaceCoords_D)* &
     2.0/dot_product(FaceCoords_D,FaceCoords_D)
    URefl_D = FaceCoords_D*UdotR

    VarsGhostFace_V = VarsTrueFace_V

    if (UdotR > 0.0) then
       VarsGhostFace_V(Rho_)  = SW_rho*BodyNDim_I(1)
       VarsGhostFace_V(P_)= SW_p*6.0e-3
       VarsGhostFace_V(RhoUx_:RhoUz_) = 0.0
       ! VarsGhostFace_V(Bx_:Bz_) = 0.0 float mag. field
    endif
    call test_stop(NameSub, DoTest)
  end subroutine user_set_face_boundary
  !============================================================================

end module ModUser
!==============================================================================
