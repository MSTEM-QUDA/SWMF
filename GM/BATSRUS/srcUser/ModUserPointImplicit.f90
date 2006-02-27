!^CFG COPYRIGHT UM
!========================================================================
module ModUser
  ! This is an example user module demonstrating the use of the 
  ! point implicit scheme for the user source terms.
  ! Please also see the documentation, and the ModPointImplicit.f90 file.

  use ModUserEmpty, ONLY:               &
!!!       user_read_inputs,                &
       user_init_session,               &
       user_set_ics,                    &
       user_initial_perturbation,       &
       user_set_boundary_cells,         &
       user_face_bcs,                   &
       user_set_outerbcs,               &
       user_specify_initial_refinement, &
       user_amr_criteria,               &
       user_write_progress,             &
       user_get_log_var,                &
!!!       user_calc_sources,               &
       user_heat_source,                &
       user_get_b0,                     &
       user_update_states

  include 'user_module.h' !list of public methods

  !\
  ! Here you must define a user routine Version number and a 
  ! descriptive string.
  !/
  real,              parameter :: VersionUserModule = 1.0
  character (len=*), parameter :: NameUserModule = &
       'EXAMPLE FOR POINT IMPLICIT SOURCE, Toth'

  ! Local variables with default values
  real :: rFriction = 1.0, TauFriction = 1.0

contains
  subroutine user_read_inputs

    use ModReadParam
    character (len=100) :: NameCommand

    do
       if(.not.read_line() ) EXIT
       if(.not.read_command(NameCommand)) CYCLE
       select case(NameCommand)
       case("#FRICTION")
          call read_var('rFriction',rFriction)
          call read_var('TauFriction',TauFriction)
       case('#USERINPUTEND')
          EXIT
       case default
          call stop_mpi('ERROR in ModUserPointImplicit: unknown command='//&
               NameCommand)
       end select
    end do

  end subroutine user_read_inputs

  !==========================================================================
  subroutine user_calc_sources

    ! Evaluate the explicit or implicit or both source terms.
    ! If there is no explicit source term, the subroutine user_expl_source 
    ! and the corresponding calls can be removed.

    use ModPointImplicit, ONLY: UsePointImplicit, IsPointImplSource

    if(.not.UsePointImplicit)then
       ! Add all source terms if we do not use the point implicit scheme
       call user_expl_source
       call user_impl_source
    elseif(IsPointImplSource)then
       ! Add implicit sources only
       call user_impl_source
    else
       ! Add explicit sources only
       call user_expl_source
    end if

  end subroutine user_calc_sources
  !==========================================================================
  subroutine user_expl_source

    ! Here come the explicit source terms

  end subroutine user_expl_source
  !==========================================================================
  subroutine user_impl_source
  
    ! This is a test and example for using point implicit source terms
    ! Apply friction relative to some medium at rest
    ! The friction force is proportional to the velocity and the density.

    use ModPointImplicit, ONLY: &
         UsePointImplicit, iVarPointImpl_I, IsPointImplMatrixSet, DsDu_VVC

    use ModMain,    ONLY: GlobalBlk, nI, nJ, nK
    use ModAdvance, ONLY: State_VGB, Source_VC, &
         Rho_, RhoUx_, RhoUy_, RhoUz_, Energy_
    use ModGeometry,ONLY: r_BLK

    integer :: iBlock, i, j, k
    real    :: Coef
    !-------------------------------------------------------------------------

    iBlock = GlobalBlk

    ! Initialization for implicit sources
    if(UsePointImplicit .and. .not.allocated(iVarPointImpl_I))then

       ! Allocate and set iVarPointImpl_I
       ! In this example there are 3 implicit variables
       allocate(iVarPointImpl_I(3))

       ! In this example the implicit variables are the 3 momenta
       iVarPointImpl_I = (/RhoUx_, RhoUy_, RhoUz_/)

       ! Note that energy is not an independent variable for the 
       ! point implicit scheme. The pressure is an independent variable,
       ! and in this example there is no implicit pressure source term.

       ! Tell the point implicit scheme if dS/dU will be set analytically
       ! If this is set to true the DsDu_VVC matrix has to be set below.
       IsPointImplMatrixSet = .true.

       RETURN
    end if

    ! Add implicit source here
    ! In this example a simple friction term is added to the momentum and 
    ! energy equtaions.
    Coef = 1.0/TauFriction

    do k=1,nK; do j=1,nJ; do i=1,nI
       if(r_BLK(i,j,k,iBlock) > rFriction ) CYCLE

       ! Friction force F = (1/TauFriction)*RhoU
       Source_VC(RhoUx_:RhoUz_,i,j,k) = Source_VC(RhoUx_:RhoUz_,i,j,k) &
            - Coef * State_VGB(RhoUx_:RhoUz_,i,j,k,iBlock)

       ! Kinetic energy changes by F.v = (1/TauFriction)*rhoU^2/rho
       Source_VC(Energy_,i,j,k) = Source_VC(Energy_,i,j,k) &
            - Coef * sum(State_VGB(RhoUx_:RhoUz_,i,j,k,iBlock)**2) &
            / State_VGB(Rho_,i,j,k,iBlock)

    end do; end do; end do

    if(IsPointImplMatrixSet)then
       ! Set the non-zero dS/dU matrix elements here
       do k=1,nK; do j=1,nJ; do i=1,nI
          if( r_BLK(i,j,k,iBlock) > rFriction ) CYCLE
          DsDu_VVC(RhoUx_,RhoUx_,i,j,k) = - Coef
          DsDu_VVC(RhoUy_,RhoUy_,i,j,k) = - Coef
          DsDu_VVC(RhoUz_,RhoUz_,i,j,k) = - Coef
       end do; end do; end do
    end if

  end subroutine user_impl_source

end module ModUser
