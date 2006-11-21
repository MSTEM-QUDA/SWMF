! You must set UseUserInitSession, UseUserSetIcs and UseUserOuterBcs 
! to .true. for this user module to be effective.

!========================================================================
Module ModUser
  use ModNumConst, ONLY: cHalf,cTwo,cThree,&
       cFour,cE1,cHundred,cHundredth,cZero,&
       cOne,cTiny
  use ModSize,     ONLY: nI,nJ,nK,gcn,nBLK
  use ModUserEmpty,               &
       IMPLEMENTED1 => user_init_session,               &
       IMPLEMENTED2 => user_set_ics,                    &
       IMPLEMENTED3 => user_set_outerbcs

  include 'user_module.h' !list of public methods
 
  real, parameter :: VersionUserModule = 1.0
  character (len=*), parameter :: &
       NameUserModule = 'Magnetosphere 2 Species (SwIono), Hansen, May, 2006'

contains

  !=====================================================================
  subroutine user_init_session

  use ModVarIndexes
  use ModPhysics, ONLY: FaceState_VI, CellState_VI, SW_rho, Body_rho
  use ModNumConst, ONLY: cTiny
  use ModSize, ONLY: east_, west_, south_, north_, bot_, top_
  use ModMain, ONLY: body1_
  integer :: iBoundary

    !-------------------------------------------------------------------

    !\
    ! We are using this routine to initialize the arrays that control the
    ! default value for the inner body and hence the boundary condition.
    ! Note these values are typically set in set_physics and they are set the 
    ! to Body_Rho value which is read from the PARAM.in file.  We want to use 
    ! this same strategy for multi-species but have to do it here to avoid 
    ! modifying the core source code.
    !/
    
    ! FaceState_VI is used to set the inner boundary condition.  Setting
    ! the correct values here for the extra species will assure that 
    ! the inner boundary is done correctly.
    FaceState_VI(rhosw_,body1_) =cTiny*Body_rho
    FaceState_VI(rhoion_,body1_)=Body_rho
  
    ! We set the following array for the outer boundaries.  Although
    ! only CellState_VI is used we set both.  Not that these are 
    ! used for only some outerboundary cases (fixed, for example) and
    ! are ignored for vary and other types.  We code them as in set_physics
    ! just to be safe.
    do iBoundary=east_,top_
       FaceState_VI(rhosw_, iBoundary)  = SW_rho
       FaceState_VI(rhoion_, iBoundary) = cTiny*sw_rho
    end do
    CellState_VI=FaceState_VI

  end subroutine user_init_session

  !=====================================================================
  subroutine user_set_ics
    use ModMain,     ONLY: globalBLK
    use ModGeometry, ONLY: r_BLK
    use ModAdvance,  ONLY: State_VGB, rhoion_, rhosw_
    use ModPhysics,  ONLY: Body_Rho, sw_rho, rBody
    use ModNumConst, ONLY: cTiny
    implicit none

    integer :: iBlock
    !--------------------------------------------------------------------------
    iBlock = globalBLK

    where(r_BLK(:,:,:,iBlock)<2.0*Rbody)
       State_VGB(rhoion_,:,:,:,iBlock) = Body_Rho
       State_VGB(rhosw_,:,:,:,iBlock)  = cTiny*sw_rho
    elsewhere
       State_VGB(rhoion_,:,:,:,iBlock) = cTiny*Body_Rho
       State_VGB(rhosw_,:,:,:,iBlock)  = sw_rho
    end where

  end subroutine user_set_ics


  !=====================================================================
  subroutine user_set_outerbcs(iBlock,iSide, TypeBc,found)

  use ModMain,      ONLY : time_simulation
  use ModMain,      ONLY : time_accurate
  use ModVarIndexes
  use ModAdvance,   ONLY : State_VGB
  use ModPhysics,   ONLY : CellState_VI

    integer,intent(in)::iBlock, iSide
    logical,intent(out) :: found
    character (len=20),intent(in) :: TypeBc
    real :: time_now

    character (len=*), parameter :: Name='user_set_outerbcs'

    time_now = time_simulation

    !-------------------------------------------------------------------

    if(TypeBc=='vary'.and.time_accurate)then
       call BC_solar_wind(time_now)
    else
       call BC_fixed(1,nVar,CellState_VI(:,iSide))
       call BC_fixed_B
    end if

    ! Note that the above code does not set the extra density species (vary)
    ! or sets them to undefined values (fixed). 
    !
    ! The solar wind species is the only one at the upstream boundary.
    ! The ionosphere species is zero.
    State_VGB(rhosw_,:,:,:,iBlock)   = State_VGB(rho_,:,:,:,iBlock)
    State_VGB(rhoion_,:,:,:,iBlock)  = cTiny*State_VGB(rho_,:,:,:,iBlock)

    found = .true.

  end subroutine user_set_outerbcs


end module ModUser

