module ModSetOuterBC

  ! Notation: 1g - first ghost cell,    2g - second ghost cell
  !           1p - first physical cell, 2p - second physical cell

  integer :: imin1g,imax1g,imin2g,imax2g,imin1p,imax1p,imin2p,imax2p
  integer :: jmin1g,jmax1g,jmin2g,jmax2g,jmin1p,jmax1p,jmin2p,jmax2p
  integer :: kmin1g,kmax1g,kmin2g,kmax2g,kmin1p,kmax1p,kmin2p,kmax2p
  integer :: iBLK

end module ModSetOuterBC

!=============================================================================

module ModFaceBc

  ! Variables shared by subroutines set_BCs.f90 and user_face_bcs in ModUser
  
  use ModVarIndexes, ONLY: nVar

  implicit none

  SAVE

  ! True if only boundaries at resolution changes are updated
  logical:: DoResChangeOnly

  ! The type and index of the boundary
  character(len=20) :: TypeBc

  ! Negative iBoundary indicates which body we are computing for.
  ! Positive iBoundary numerates the sides for the outer BCs.
  integer:: iBoundary

  ! Index of the face
  integer:: iFace, jFace, kFace, iBlockBc

  ! The side of the cell defined with respect to the cell inside the domain
  integer :: iSide

  ! The values on the physical side and the ghost cell side of the boudary
  real:: VarsTrueFace_V(nVar), VarsGhostFace_V(nVar)

  ! The coordinates of the face center and the B0 field at that point
  real :: FaceCoords_D(3), B0Face_D(3)

  ! The time at which the (time dependent) boundary condition is calculated
  real :: TimeBc

end module ModFaceBc

!============================================================================

module ModBoundaryCells

  implicit none
  SAVE

  logical::SaveBoundaryCells=.false.
  logical::ResetBody2Cells=.false.
  integer::MinBoundarySaved=-777,MaxBoundarySaved=-777,nBoundarySaved=0
  logical,allocatable,dimension(:,:,:,:,:)::IsBoundaryCell_IGB
  ! iBoundary_GB contains the index of the boundary that the cell belongs to.
  integer , allocatable :: iBoundary_GB(:,:,:,:)

  ! Cells inside domain have index domain_ that is smaller than smallest 
  ! boundary index (body2_ = -2)
  integer, parameter :: domain_ = -10

  ! The DomainOp sets the operator applied for boundary indexes
  ! in ghost cells that are restricted. So the largest index is kept.
  character(len=*), parameter :: DomainOp='max'

contains

  !===========================================================================
  subroutine init_mod_boundary_cells

    use ModSize
    use ModGeometry, ONLY: MaxBoundary
    use ModMain,     ONLY: UseExtraBoundary, ExtraBC_, UseBatl
    use ModProcMH
    !-------------------------------------------------------------------------

    if(UseBatl .and. .not. allocated(iBoundary_GB)) then
       allocate(iBoundary_GB(MinI:MaxI,MinJ:MaxJ,MinK:MaxK,MaxBlock))
       iBoundary_GB = domain_
    end if

    if(.not.UseBatl .and. .not.SaveBoundaryCells) then
       if(iProc==0)write(*,*)&
            'Do not allocate boundary cell array, if SaveBoundaryCells=',&
            SaveBoundaryCells
       return
    end if

    if(.not.UseBatl .and. allocated(IsBoundaryCell_IGB))return

    if(UseExtraBoundary)then
       MinBoundarySaved=ExtraBC_
    else
       MinBoundarySaved=ExtraBC_+1
    end if
    MaxBoundarySaved=MaxBoundary
    if(MaxBoundarySaved < MinBoundarySaved)then
       if(iProc==0)write(*,*)'Only Extra and Outer boundary cells can be saved'
       SaveBoundaryCells=.false.
    end if
    nBoundarySaved = MaxBoundarySaved - MinBoundarySaved + 1

    if(.not.UseBatl)then 
       if(.not.allocated(IsBoundaryCell_IGB)) &
            allocate(IsBoundaryCell_IGB(MinBoundarySaved:MaxBoundarySaved,&
            1-gcn:nI+gcn, 1-gcn:nJ+gcn,  1-gcn:nK+gcn, nBLK))
    end if

  end subroutine init_mod_boundary_cells

end module ModBoundaryCells

!=============================================================================

subroutine fix_boundary_ghost_cells(UseMonotoneRestrict)

  use ModBoundaryCells, ONLY: MinBoundarySaved, MaxBoundarySaved, &
       IsBoundaryCell_IGB, iBoundary_GB, DomainOp, domain_
  use ModMain, ONLY : nBlock, UnusedBlk, iNewGrid, iNewDecomposition, nOrder,&
       UseBatl, nI, nJ, nK, body2_, Top_, &
       BlkTest, iTest, jTest, kTest
  use ModGeometry, ONLY: true_cell, body_BLK, IsBoundaryBlock_IB,&
       x_BLK, y_BLK, z_BLK
  !use ModProcMH, ONLY: iProc
  use BATL_lib, ONLY: message_pass_cell_scalar

  implicit none

  logical, intent(in):: UseMonotoneRestrict

  integer:: i,j,k
  integer:: iBlock, iBoundary
  integer:: iGridHere=-1, iDecompositionHere=-1, nOrderHere=-1

  logical:: DoTest, DoTestMe
  character(len=*), parameter:: NameSub = 'fix_boundary_ghost_cells'
  !----------------------------------------------------------------------------
  call set_oktest(NameSub, DoTest, DoTestMe)

  if(DoTestMe) write(*,*) NameSub,' UseMonotone=',UseMonotoneRestrict

  ! Recalculate ghost cell info if grid changed. If BATL is not used,
  ! also has to redo it if the order of the scheme changed.
  ! Depending on what the boundary cell info in the ghost cells is used for,
  ! this condition may have to be revised !!!
  if(iGridHere==iNewGrid .and. iDecompositionHere==iNewDecomposition &
       .and. (nOrderHere==nOrder .or. UseBatl)) RETURN

  iGridHere=iNewGrid; iDecompositionHere=iNewDecomposition; nOrderHere=nOrder

  if(DoTestMe) write(*,*)NameSub,' starting with true_cell(i-2:i+2)=', &
       true_cell(iTest-2:iTest+2,jTest,kTest,BlkTest)

  if(UseBatl) then
     call message_pass_cell_scalar(Int_GB=iBoundary_GB, &
          nProlongOrderIn=1, nCoarseLayerIn=2, &
          DoSendCornerIn=.true., DoRestrictFaceIn=.true., &
          NameOperatorIn=DomainOp)

     if(DoTestMe) write(*,*) NameSub,': iBoundary_GB(i-2:i+2)=', &
          iBoundary_GB(iTest-2:iTest+2,jTest,kTest,BlkTest)

     do iBlock = 1, nBlock
        if(unusedBLK(iBlock)) CYCLE

        true_cell(:,:,:,iBlock) = true_cell(:,:,:,iBlock)  &
             .and. (iBoundary_GB(:,:,:,iBlock) == domain_)

        body_BLK(iBlock) = .not. all(true_cell(:,:,:,iBlock))   

        do iBoundary = body2_, Top_
           IsBoundaryBlock_IB(iBoundary,iBlock)= &
                any(iBoundary_GB(:,:,:,iBlock) == iBoundary)
        end do
     end do
  else
     if(DoTestMe) write(*,*) NameSub,': MinBoundarySaved, MaxBoundarySaved=', &
          MinBoundarySaved, MaxBoundarySaved

     call message_pass_boundary_cells(UseMonotoneRestrict)

     if(DoTestMe) write(*,*) NameSub, ': IsBoundaryCell_IGB = ', &
          IsBoundaryCell_IGB(:,iTest,jTest,kTest,BlkTest)

     do iBlock = 1, nBlock

        if(unusedBLK(iBlock)) CYCLE

        do iBoundary = MinBoundarySaved, MaxBoundarySaved
           IsBoundaryBlock_IB(iBoundary,iBlock)=&
                any(IsBoundaryCell_IGB(iBoundary,:,:,:,iBlock))
           true_cell(:,:,:,iBlock) = true_cell(:,:,:,iBlock) &
                .and. .not.IsBoundaryCell_IGB(iBoundary,:,:,:,iBlock)
        end do

        ! body_BLK: if any cell INCLUDING ghost cells is outside 
        ! the comp. domain
        body_BLK(iBlock) = .not. all(true_cell(:,:,:,iBlock))

     end do
  end if

  if(DoTestMe) write(*,*) NameSub,' finished with true_cell(i-2:i+2)=', &
       true_cell(iTest-2:iTest+2,jTest,kTest,BlkTest)

end subroutine fix_boundary_ghost_cells
