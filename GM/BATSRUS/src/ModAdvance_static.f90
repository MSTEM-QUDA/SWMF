!^CFG COPYRIGHT UM
Module ModAdvance
  use ModSize
  use ModVarIndexes
  use ModIO,         ONLY: iUnitOut, write_prefix
  use ModProcMH,     ONLY: iProc, nProc

  implicit none
  save

  ! Logical parameter indicating static vs. dynamic allocation
  logical, parameter :: IsDynamicAdvance = .false.

  ! Numerical flux type
  character (len=10) :: FluxType

  !\ One of the two possible ways to treat the MHD-like systems
  !  (oartially symmetrizable, following the Godunov definition).
  !  If the UseRS7=.true. then the 7 waves Riemann Solver (RS) with 
  !  continuous  normal component of the magnetic field across the face.
  !  The number of jumps in the physical variables across the face is equal
  !  to the number of waves, resulting in the the well-posed solution os
  !  the Riemann problem. This approach is alternative to the 8-wave scheme

  logical::UseRS7

  ! Update check parameters
  logical :: UseUpdateCheck
  real :: percent_max_rho(2), percent_max_p(2)

  ! The percentage limit for species to be checked in update check
  real :: SpeciesPercentCheck = 1.0

  ! Replace density with sum of species densities (in multi-species plasma)
  logical :: DoReplaceDensity = .true.

  !\
  ! Conservative/Non-conservative parameters
  !/
  logical :: UseNonConservative

  ! Number and type of criteria
  integer :: nConservCrit
  character (len=10), allocatable :: TypeConservCrit_I(:)

  ! Geometrical parameters
  real    :: rConserv, xParabolaConserv, yParabolaConserv 

  ! Physics based parameters (to locate shocks)
  real    :: pCoeffConserv, GradPCoeffConserv

  ! Cells selected to be updated with conservative equations
  logical, allocatable :: IsConserv_CB(:,:,:,:)

  !\
  ! Block cell-centered MHD solution
  !/
  real:: State_VGB(nVar,1-gcn:nI+gcn, 1-gcn:nJ+gcn, 1-gcn:nK+gcn, MaxBlock)
  real:: Energy_GBI(1-gcn:nI+gcn, 1-gcn:nJ+gcn, 1-gcn:nK+gcn, MaxBlock, nFluid)

  !\
  ! Block cell-centered MHD solution old state
  !/
  real :: StateOld_VCB(nVar, nI, nJ, nK, MaxBlock)
  real :: EnergyOld_CBI(nI, nJ, nK, MaxBlock, nFluid)

  !\
  ! Block cell-centered intrinsic magnetic field, time, and temporary storage
  !/
  real,  dimension(1-gcn:nI+gcn, 1-gcn:nJ+gcn, 1-gcn:nK+gcn, MaxBlock) :: &
       B0xCell_BLK, B0yCell_BLK, B0zCell_BLK, &
       tmp1_BLK, tmp2_BLK

  real :: time_BLK(nI, nJ, nK, MaxBlock)

  ! Array for storing dB0/dt derivatives
  real, allocatable :: Db0Dt_CDB(:,:,:,:,:)

  ! Arrays for the total electric field
  real, dimension(nI, nJ, nK, MaxBlock) :: Ex_CB, Ey_CB, Ez_CB

  !\
  ! Block cell-centered body forces
  !/
  real, dimension(nI, nJ, nK, MaxBlock) :: &
       fbody_x_BLK, fbody_y_BLK, fbody_z_BLK

  !\
  ! Local cell-centered source terms and divB.
  !/
  real :: Source_VC(nVar+nFluid, nI, nJ, nK)
  real :: Theat0(nI,nJ,nK)
  real :: DivB1_GB(1-gcn:nI+gcn, 1-gcn:nJ+gcn, 1-gcn:nK+gcn, MaxBlock)

  real, dimension(0:nI+1, 0:nJ+1, 0:nK+1) :: &
       gradX_Ux, gradX_Uy, gradX_Uz, gradX_Bx, gradX_By, gradX_Bz, gradX_VAR,&
       gradY_Ux, gradY_Uy, gradY_Uz, gradY_Bx, gradY_By, gradY_Bz, gradY_VAR,&
       gradZ_Ux, gradZ_Uy, gradZ_Uz, gradZ_Bx, gradZ_By, gradZ_Bz, gradZ_VAR

  !\
  ! Block face-centered intrinsic magnetic field array definitions.
  !/
  real, dimension(2-gcn:nI+gcn, 0:nJ+1, 0:nK+1, MaxBlock) :: &
       B0xFace_x_BLK, B0yFace_x_BLK, B0zFace_x_BLK 

  real, dimension(0:nI+1, 2-gcn:nJ+gcn, 0:nK+1, MaxBlock) :: &
       B0xFace_y_BLK, B0yFace_y_BLK, B0zFace_y_BLK

  real, dimension(0:nI+1, 0:nJ+1, 2-gcn:nK+gcn, MaxBlock) :: &
       B0xFace_z_BLK, B0yFace_z_BLK, B0zFace_z_BLK

  real :: CurlB0_DCB(3, nI, nJ, nK, MaxBlock)
  real :: DivB0_CB(nI, nJ, nK, MaxBlock)
  real :: NormB0_CB(nI,nJ,nK,MaxBlock)

  !\
  ! X Face local MHD solution array definitions.
  !/
  integer, parameter :: nFaceValueVars = nVar
  real :: LeftState_VX(nFaceValueVars,2-gcn:nI+gcn,0:nJ+1,0:nK+1)
  real :: RightState_VX(nFaceValueVars,2-gcn:nI+gcn,0:nJ+1,0:nK+1)

  real :: EDotFA_X(2-gcn:nI+gcn,0:nJ+1,0:nK+1)    !^CFG IF BORISCORR
  real :: VdtFace_X(2-gcn:nI+gcn,0:nJ+1,0:nK+1)   ! V/dt Face X

  real :: Flux_VX(nVar+nFluid,0:nI+1,2-gcn:nJ+gcn,0:nK+1)

  real :: uDotArea_XI(2-gcn:nI+gcn,0:nJ+1,0:nK+1,nFluid)

  real :: bCrossArea_DX(3,2-gcn:nI+gcn,0:nJ+1,0:nK+1)

  !\
  ! Y Face local MHD solution array definitions.
  !/
  real :: LeftState_VY(nFaceValueVars,0:nI+1,2-gcn:nJ+gcn,0:nK+1)
  real :: RightState_VY(nFaceValueVars,0:nI+1,2-gcn:nJ+gcn,0:nK+1)

  real :: EDotFA_Y(0:nI+1,2-gcn:nJ+gcn,0:nK+1)    !^CFG IF BORISCORR
  real :: VdtFace_Y(0:nI+1,2-gcn:nJ+gcn,0:nK+1)   ! V/dt Face Y

  real :: Flux_VY(nVar+nFluid,0:nI+1,2-gcn:nJ+gcn,0:nK+1)

  real :: uDotArea_YI(0:nI+1,2-gcn:nJ+gcn,0:nK+1,nFluid)

  real :: bCrossArea_DY(3,0:nI+1,2-gcn:nJ+gcn,0:nK+1)

  !\
  ! Z Face local MHD solution array definitions.
  !/
  real :: LeftState_VZ(nFaceValueVars,0:nI+1,0:nJ+1,2-gcn:nK+gcn)
  real :: RightState_VZ(nFaceValueVars,0:nI+1,0:nJ+1,2-gcn:nK+gcn)

  real :: EDotFA_Z(0:nI+1,0:nJ+1,2-gcn:nK+gcn)    !^CFG IF BORISCORR
  real :: VdtFace_z(0:nI+1,0:nJ+1,2-gcn:nK+gcn)   ! V/dt Face Z

  real :: Flux_VZ(nVar+nFluid,0:nI+1,0:nJ+1,2-gcn:nK+gcn)

  real :: uDotArea_ZI(0:nI+1,0:nJ+1,2-gcn:nK+gcn,nFluid)

  real :: bCrossArea_DZ(3,0:nI+1,0:nJ+1,2-gcn:nK+gcn)

  !\
  ! The number of the face variables, which are corrected at the
  ! resolution changes
  !/

  !\
  !  Face conservative or corrected flux.
  !/
  real :: CorrectedFlux_VXB(nCorrectedFaceValues, nJ, nK, 2, MaxBlock)
  real :: CorrectedFlux_VYB(nCorrectedFaceValues, nI, nK, 2, MaxBlock)
  real :: CorrectedFlux_VZB(nCorrectedFaceValues, nI, nJ, 2, MaxBlock)

  !\
  ! Block type information
  !/
  integer              :: iTypeAdvance_B(MaxBlock)
  integer, allocatable :: iTypeAdvance_BP(:,:)

  ! Named indexes for block types
  integer, parameter :: &
       SkippedBlock_=0,     & ! Blocks which were unused originally.
       SteadyBlock_=1,      & ! Blocks which do not change
       SteadyBoundBlock_=2, & ! Blocks surrounding the evolving blocks
       ExplBlock_=3,        & ! Blocks changing with the explicit scheme
       ImplBlock_=4           ! Blocks changing with the implicit scheme

contains

  !============================================================================

  subroutine init_mod_advance

    if(allocated(iTypeAdvance_BP)) RETURN
    allocate(iTypeAdvance_BP(MaxBlock,0:nProc-1))
    iTypeAdvance_B  = SkippedBlock_
    iTypeAdvance_BP = SkippedBlock_

    if(IsDynamicAdvance .and. iProc==0)then
       call write_prefix
       write(iUnitOut,'(a)') 'init_mod_advance allocated arrays'
    end if

  end subroutine init_mod_advance

  !============================================================================

  subroutine clean_mod_advance

    if(allocated(iTypeAdvance_BP)) deallocate(iTypeAdvance_BP)

    if(IsDynamicAdvance .and. iProc==0)then
       call write_prefix
       write(iUnitOut,'(a)') 'clean_mod_advance deallocated arrays'
    end if

  end subroutine clean_mod_advance

  !============================================================================

end Module ModAdvance
