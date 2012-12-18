!This code is a copyright protected software (c) 2002- University of Michigan
module ModConserveFlux

  use BATL_size, ONLY: nDim, MaxDim
  use ModSize, ONLY: nI, nJ, nK, MaxBlock
  use ModVarIndexes, ONLY: nFluid, nVar, Bx_, By_, Bz_,B_,U_

  use ModProcMH, ONLY: iProc
  use ModMain, ONLY: BlkTest, ProcTest, iTest, jTest, kTest,UseB
  use ModAdvance, ONLY: &
       Flux_VX, Flux_VY, Flux_VZ, &
       VdtFace_X, VdtFace_Y, VdtFace_Z, &
       LeftState_VX, LeftState_VY, LeftState_VZ, &
       RightState_VX, RightState_VY, RightState_VZ, &
       uDotArea_XI, uDotArea_YI, uDotArea_ZI

  use ModGeometry,  ONLY: true_cell
  use ModParallel, ONLY : &
       neiLtop, neiLbot, neiLeast, neiLwest, neiLnorth, neiLsouth, &
       neiPtop, neiPbot, neiPeast, neiPwest, neiPnorth, neiPsouth, &
       neiBtop, neiBbot, neiBeast, neiBwest, neiBnorth, neiBsouth
  use BATL_lib, ONLY: &
       IsCartesianGrid, IsCartesian, IsRzGeometry, &
       CellFace_DFB, FaceNormal_DDFB, Unused_BP


  implicit none

  private ! except

  public:: &
       init_cons_flux, &
       save_cons_flux, &
       apply_cons_flux, &
       nCorrectedFaceValues, &
       CorrectedFlux_VXB, &
       CorrectedFlux_VYB, &
       CorrectedFlux_VZB

  integer, parameter :: &
       FluxLast_ = nVar + nFluid, &
       UnFirst_=FluxLast_+1, UnLast_ = UnFirst_ + nFluid, &
       Vdt_ = UnLast_ + 1
  !The normal components of the magnetic field is exchaned only for
  !B_>U_ (UseB_ is true)
  integer,parameter :: BnL_ = Vdt_ + min(1, B_-U_) 
  integer,parameter :: BnR_ = BnL_ + min(1, B_-U_)
  integer,parameter :: nCorrectedFaceValues = BnR_

  ! Face conservative or corrected flux.
  real, allocatable, dimension(:,:,:,:,:) :: &
       CorrectedFlux_VXB, CorrectedFlux_VYB, CorrectedFlux_VZB

  real, parameter :: FaceRatio = 1.0/2**(nDim-1)

contains

  !===========================================================================

  subroutine init_cons_flux(iBlock)

    integer,intent(in) :: iBlock
    !--------------------------------------------------------------------------
    if(.not.allocated(CorrectedFlux_VXB)) allocate( &
         CorrectedFlux_VXB(nCorrectedFaceValues,nJ,nK,2,MaxBlock), &
         CorrectedFlux_VYB(nCorrectedFaceValues,nI,nK,2,MaxBlock), &
         CorrectedFlux_VZB(nCorrectedFaceValues,nI,nJ,2,MaxBlock)  )

    CorrectedFlux_VXB(:,:,:,:,iBlock) = 0.0
    CorrectedFlux_VYB(:,:,:,:,iBlock) = 0.0
    CorrectedFlux_VZB(:,:,:,:,iBlock) = 0.0

  end subroutine init_cons_flux

  !============================================================================

  subroutine save_cons_flux(iBlock)

    integer, intent(in) :: iBlock

    logical :: DoTest, DoTestMe
    integer :: lFaceFrom,lFaceTo,i,j,k
    character(len=*), parameter :: NameSub = 'save_cons_flux'
    !--------------------------------------------------------------------------

    if(iProc==PROCtest .and. iBlock==BLKtest)then
       call set_oktest(NameSub, DoTest, DoTestMe)
    else
       DoTest=.false.; DoTestMe=.false.
    end if

    if (neiLeast(iBlock)==+1) then
       lFaceFrom=1
       lFaceTo=1
       call save_corrected_flux_x
    end if

    if (neiLwest(iBlock)==+1) then
       lFaceFrom=1+nI
       lFaceTo=2
       call save_corrected_flux_x
    end if

    if (nDim > 1 .and. neiLsouth(iBlock)==+1) then
       lFaceFrom=1
       lFaceTo=1
       call save_corrected_flux_y
    end if

    if (nDim > 1 .and. neiLnorth(iBlock)==+1) then
       lFaceFrom=1+nJ
       lFaceTo=2
       call save_corrected_flux_y
    end if

    if (nDim > 2 .and. neiLbot(iBlock)==+1) then
       lFaceFrom=1
       lFaceTo=1
       call save_corrected_flux_z
    end if

    if (nDim > 2 .and. neiLtop(iBlock)==+1) then
       lFaceFrom=nK+1
       lFaceTo=2
       call save_corrected_flux_z
    end if

  contains

    !==========================================================================

    subroutine save_corrected_flux_x

      do k=1,nK; do j=1,nJ
         CorrectedFlux_VXB(1:FluxLast_, j, k, lFaceTo, iBlock)  &
              = Flux_VX(1:nVar+nFluid, lFaceFrom,j,k)

         CorrectedFlux_VXB(UnFirst_:UnLast_,j,k,lFaceTo,iBlock) &
              = uDotArea_XI(lFaceFrom,j,k,:)

         CorrectedFlux_VXB(Vdt_,   j,k,lFaceTo,iBlock)          &
              = VdtFace_x(lFaceFrom,j,k)
      end do; end do

      if(.not.UseB)RETURN

      if(IsCartesian)then
         do k=1,nK; do j=1,nJ
            CorrectedFlux_VXB(BnL_,j,k,lFaceTo,iBlock)= &
                 LeftState_VX(Bx_,lFaceFrom,j,k)*FaceRatio
            CorrectedFlux_VXB(BnR_,j,k,lFaceTo,iBlock)= &
                 RightState_VX(Bx_,lFaceFrom,j,k)*FaceRatio
         end do; end do
      elseif(IsRzGeometry)then
         ! X face areas vary in RZ geometry
         do k=1,nK; do j=1,nJ
            CorrectedFlux_VXB(BnL_,j,k,lFaceTo,iBlock) = &
                 LeftState_VX(Bx_, lFaceFrom,j,k) * &
                 CellFace_DFB(1,lFaceFrom,j,k,iBlock)
            CorrectedFlux_VXB(BnR_,j,k,lFaceTo,iBlock) = &
                 RightState_VX(Bx_,lFaceFrom,j,k) * &
                 CellFace_DFB(1,lFaceFrom,j,k,iBlock)
         end do; end do
      else
         ! Dot product with face normal
         do k=1,nK; do j=1,nJ
            CorrectedFlux_VXB(BnL_, j, k, lFaceTo, iBlock) = &
                 dot_product(LeftState_VX(Bx_:B_+nDim, lFaceFrom, j, k), &
                 FaceNormal_DDFB(:,1,lFaceFrom, j, k, iBlock))
            CorrectedFlux_VXB(BnR_, j, k, lFaceTo, iBlock) = &
                 dot_product(RightState_VX(Bx_:B_+nDim,lFaceFrom, j, k), &
                 FaceNormal_DDFB(:,1,lFaceFrom,j,k,iBlock))
         end do; end do
      end if

      if(DoTestMe)then
         
         write(*,*)NameSub,' lFaceFrom, lFaceTo=',lFaceFrom, lFaceTo
         do i = 1, nFluid+1
            write(*,*)NameSub,' iVar, uDotA=', &
                 uDotArea_XI(lFaceFrom,jTest,kTest,i)
         end do
         do i = 1, nCorrectedFaceValues
            write(*,*)NameSub,' iVar, flux=', i, &
                 CorrectedFlux_VXB(i, iTest, jTest, kTest, iBlock)
         end do
      end if

    end subroutine save_corrected_flux_x

    !==========================================================================

    subroutine save_corrected_flux_y

      do k=1,nK;do i=1,nI
         CorrectedFlux_VYB(1:FluxLast_,  i,k,lFaceTo,iBlock)    &
              = Flux_VY(1:FluxLast_,i,lFaceFrom,k)

         CorrectedFlux_VYB(UnFirst_:UnLast_,i,k,lFaceTo,iBlock) &
              = uDotArea_YI(i,lFaceFrom,k,:)

         CorrectedFlux_VYB(Vdt_, i, k, lFaceTo, iBlock)         &
              = VdtFace_y(i, lFaceFrom, k)
      end do; end do

      if(.not.UseB)RETURN

      if(IsCartesianGrid)then
         do k=1,nK; do i=1,nI
            CorrectedFlux_VYB(BnL_, i, k, lFaceTo, iBlock)= &
                 LeftState_VY( By_, i, lFaceFrom, k)*FaceRatio
            CorrectedFlux_VYB(BnR_, i, k, lFaceTo, iBlock)= &
                 RightState_VY(By_, i, lFaceFrom, k)*FaceRatio
         end do; end do
      else
         do k=1,nK; do i=1,nI
            CorrectedFlux_VYB(BnL_, i, k, lFaceTo, iBlock) = &
                 dot_product(LeftState_VY(Bx_:B_+nDim, i, lFaceFrom, k),&
                 FaceNormal_DDFB(:,2,i,lFaceFrom,k,iBlock))
            CorrectedFlux_VYB(BnR_, i, k, lFaceTo, iBlock) = &
                 dot_product(RightState_VY(Bx_:B_+nDim,i,lFaceFrom, k),&
                 FaceNormal_DDFB(:,2,i,lFaceFrom,k,iBlock))
         end do; end do
      end if

    end subroutine save_corrected_flux_y

    !==========================================================================

    subroutine save_corrected_flux_z

      do j=1,nJ;do i=1,nI
         CorrectedFlux_VZB(1:FluxLast_,  i,j,lFaceTo,iBlock)    &
              = Flux_VZ(1:FluxLast_,i,j,lFaceFrom)

         CorrectedFlux_VZB(UnFirst_:UnLast_,i,j,lFaceTo,iBlock) &
              = uDotArea_ZI(i,j,lFaceFrom,:)

         CorrectedFlux_VZB(Vdt_,  i,j,lFaceTo,iBlock)           &
              = VdtFace_z(i,j,lFaceFrom)
      end do; end do

      if(.not.UseB)RETURN

      if(IsCartesianGrid)then
         do j=1,nJ; do i=1,nI
            CorrectedFlux_VZB(BnL_,i,j,lFaceTo, iBlock)= &
                 LeftState_VZ( Bz_,i,j,lFaceFrom)*FaceRatio
            CorrectedFlux_VZB(BnR_,i,j,lFaceTo, iBlock)= &
                 RightState_VZ(Bz_,i,j,lFaceFrom)*FaceRatio
         end do; end do
      else
         do j=1,nJ; do i=1,nI
            CorrectedFlux_VZB(BnL_,i,j,lFaceTo,iBlock) = &
                 dot_product(LeftState_VZ(Bx_:B_+nDim,i,j,lFaceFrom),&
                 FaceNormal_DDFB(:,3,i,j,lFaceFrom,iBlock))
            CorrectedFlux_VZB(BnR_,i,j,lFaceTo, iBlock) =&
                 dot_product(RightState_VZ(Bx_:B_+nDim,i,j,lFaceFrom),&
                 FaceNormal_DDFB(:,3,i,j,lFaceFrom,iBlock))
         end do; end do
      end if

    end subroutine save_corrected_flux_z

  end subroutine save_cons_flux

  !============================================================================

  subroutine apply_cons_flux(iBlock)

    integer, intent(in):: iBlock

    integer :: i, j, k
    logical :: DoTest, DoTestMe
    integer :: lFaceFrom, lFaceTo
    character(len=*), parameter :: NameSub = 'apply_cons_flux'
    !--------------------------------------------------------------------------

    if(iProc==PROCtest .and. iBlock==BLKtest)then
       call set_oktest(NameSub, DoTest, DoTestMe)
    else
       DoTest=.false.; DoTestMe=.false.
    end if

    if (neiLeast(iBlock)==-1)then
       if ( .not.Unused_BP(neiBeast(1,iBlock),neiPeast(1,iBlock)).and.&
            .not.Unused_BP(neiBeast(2,iBlock),neiPeast(2,iBlock)).and.&
            .not.Unused_BP(neiBeast(3,iBlock),neiPeast(3,iBlock)).and.&
            .not.Unused_BP(neiBeast(4,iBlock),neiPeast(4,iBlock)))then
          lFaceTo=1
          lFaceFrom=1
          call apply_corrected_flux_x
       end if
    end if

    if (neiLwest(iBlock)==-1) then
       if ( .not.Unused_BP(neiBwest(1,iBlock),neiPwest(1,iBlock)).and.&
            .not.Unused_BP(neiBwest(2,iBlock),neiPwest(2,iBlock)).and.&
            .not.Unused_BP(neiBwest(3,iBlock),neiPwest(3,iBlock)).and.&
            .not.Unused_BP(neiBwest(4,iBlock),neiPwest(4,iBlock)))then
          lFaceTo=nI+1
          lFaceFrom=2
          call apply_corrected_flux_x
       end if
    end if

    if (nDim > 1 .and. neiLsouth(iBlock)==-1) then
       if(.not.Unused_BP(neiBsouth(1,iBlock),neiPsouth(1,iBlock)).and.&
            .not.Unused_BP(neiBsouth(2,iBlock),neiPsouth(2,iBlock)).and.&
            .not.Unused_BP(neiBsouth(3,iBlock),neiPsouth(3,iBlock)).and.&
            .not.Unused_BP(neiBsouth(4,iBlock),neiPsouth(4,iBlock)))then
          lFaceTo=1
          lFaceFrom=1
          call apply_corrected_flux_y
       end if
    end if

    if (nDim > 1 .and. neiLnorth(iBlock)==-1) then
       if ( .not.Unused_BP(neiBnorth(1,iBlock),neiPnorth(1,iBlock)).and.&
            .not.Unused_BP(neiBnorth(2,iBlock),neiPnorth(2,iBlock)).and.&
            .not.Unused_BP(neiBnorth(3,iBlock),neiPnorth(3,iBlock)).and.&
            .not.Unused_BP(neiBnorth(4,iBlock),neiPnorth(4,iBlock)))then
          lFaceTo=nJ+1
          lFaceFrom=2
          call apply_corrected_flux_y
       end if
    end if

    if (nDim > 2 .and. neiLbot(iBlock)==-1) then
       if ( .not.Unused_BP(neiBbot(1,iBlock),neiPbot(1,iBlock)).and. &
            .not.Unused_BP(neiBbot(2,iBlock),neiPbot(2,iBlock)).and. &
            .not.Unused_BP(neiBbot(3,iBlock),neiPbot(3,iBlock)).and. &
            .not.Unused_BP(neiBbot(4,iBlock),neiPbot(4,iBlock)))then
          lFaceTo=1
          lFaceFrom=1
          call apply_corrected_flux_z
       end if
    end if

    if (nDim > 2 .and. neiLtop(iBlock)==-1) then
       if ( .not.Unused_BP(neiBtop(1,iBlock),neiPtop(1,iBlock)).and. &
            .not.Unused_BP(neiBtop(2,iBlock),neiPtop(2,iBlock)).and. &
            .not.Unused_BP(neiBtop(3,iBlock),neiPtop(3,iBlock)).and. &
            .not.Unused_BP(neiBtop(4,iBlock),neiPtop(4,iBlock))) then
          lFaceTo=nK+1
          lFaceFrom=2
          call apply_corrected_flux_z
       end if
    end if

  contains

    !==========================================================================

    subroutine apply_corrected_flux_x

      do k = 1, nK; do j = 1, nJ
         if (.not.true_cell(lFaceTo-1, j, k, iBlock)) CYCLE
         if (.not.true_cell(lFaceTo  , j, k, iBlock)) CYCLE

         Flux_VX(1:FluxLast_,lFaceTo,j,k) = &
              CorrectedFlux_VXB(1:FluxLast_,j,k,lFaceFrom,iBlock)
         uDotArea_XI(lFaceTo,j,k,:) = &
              CorrectedFlux_VXB(UnFirst_:UnLast_,j,k,lFaceFrom,iBlock)
         VdtFace_x(lFaceTo,j,k) = &
              CorrectedFlux_VXB(Vdt_,j,k,lFaceFrom,iBlock)

         if(.not.(UseB .and. IsCartesianGrid))CYCLE

         if(IsCartesian)then
            LeftState_VX(Bx_,lFaceTo,j,k) = &
                 CorrectedFlux_VXB(BnL_,j,k,lFaceFrom,iBlock)
            RightState_VX(Bx_,lFaceTo,j,k) = &
                 CorrectedFlux_VXB(BnR_,j,k,lFaceFrom,iBlock)
         else
            LeftState_VX(Bx_,lFaceTo,j,k) = &
                 CorrectedFlux_VXB(BnL_,j,k,lFaceFrom,iBlock) &
                 / CellFace_DFB(1,lFaceTo,j,k,iBlock)
            RightState_VX(Bx_,lFaceTo,j,k) = &
                 CorrectedFlux_VXB(BnR_,j,k,lFaceFrom,iBlock) &
                 / CellFace_DFB(1,lFaceTo,j,k,iBlock)
         end if

      end do; end do 
      if(UseB .and. .not.IsCartesianGrid) &
           call apply_bn_face_i(lFaceFrom, lFaceTo, iBlock)

    end subroutine apply_corrected_flux_x

    !==========================================================================

    subroutine apply_corrected_flux_y
      do k = 1, nK; do i = 1, nI
         if (.not.true_cell(i, lFaceTo-1, k, iBlock))CYCLE
         if (.not.true_cell(i, lFaceTo  , k, iBlock))CYCLE

         Flux_VY(1:FluxLast_,i,lFaceTo,k) = &
              CorrectedFlux_VYB(1:FluxLast_,i,k,lFaceFrom,iBlock)
         uDotArea_YI(i,lFaceTo,k,:) = &
              CorrectedFlux_VYB(UnFirst_:UnLast_,i,k,lFaceFrom,iBlock)
         VdtFace_y(i,lFaceTo,k)= &
              CorrectedFlux_VYB(Vdt_,i,k,lFaceFrom,iBlock)
         if(IsCartesianGrid .and. UseB)then
            LeftState_VY(By_,i,lFaceTo,k) = &
                 CorrectedFlux_VYB(BnL_,i,k,lFaceFrom,iBlock)
            RightState_VY(By_,i,lFaceTo,k) = &
                 CorrectedFlux_VYB(BnR_,i,k,lFaceFrom,iBlock)
         end if
      end do; end do 
      if(.not.IsCartesianGrid .and. UseB) &
           call apply_bn_face_j(lFaceFrom, lFaceTo, iBlock)

    end subroutine apply_corrected_flux_y

    !==========================================================================

    subroutine apply_corrected_flux_z

      do j = 1, nJ; do i = 1, nI
         if(.not.true_cell(i, j, lFaceTo-1, iBlock)) CYCLE
         if(.not.true_cell(i, j, lFaceTo  , iBlock)) CYCLE

         Flux_VZ(1:FluxLast_,i,j,lFaceTo) = &
              CorrectedFlux_VZB(1:FluxLast_,i,j,lFaceFrom,iBlock)
         uDotArea_ZI(i,j,lFaceTo,:) = &
              CorrectedFlux_VZB(UnFirst_:UnLast_,i,j,lFaceFrom,iBlock)
         VdtFace_z(i,j,lFaceTo) = &
              CorrectedFlux_VZB(Vdt_,i,j,lFaceFrom,iBlock)
         if(IsCartesianGrid .and. UseB)then
            LeftState_VZ(Bz_,i,j,lFaceTo) = &
                 CorrectedFlux_VZB(BnL_,i,j,lFaceFrom,iBlock)
            RightState_VZ(Bz_,i,j,lFaceTo) = &
                 CorrectedFlux_VZB(BnR_,i,j,lFaceFrom,iBlock)
         end if
      end do; end do 
      if(.not.IsCartesianGrid .and. UseB) &
           call apply_bn_face_k(lFaceFrom, lFaceTo, iBlock)           

    end subroutine apply_corrected_flux_z

  end subroutine apply_cons_flux

  !==========================================================================
  ! subroutines for applying Bn in generalized coordinates
  !==========================================================================

  subroutine apply_bn_face_i(iFaceIn, iFaceOut, iBlock)

    integer, intent(in):: iFaceIn, iFaceOut, iBlock

    integer:: j, k
    real:: B_D(nDim), FaceArea_D(nDim)
    real:: FaceArea2, DeltaBDotFA
    !------------------------------------------------------------------------
    do k=1,nK; do j=1,nJ
       if(.not.all(true_cell(iFaceOut-1:iFaceOut,j,k,iBlock)))CYCLE

       FaceArea_D = FaceNormal_DDFB(:,1,iFaceOut,j,k,iBlock)
       FaceArea2  = sum(FaceArea_D**2)

       if(FaceArea2 == 0.0) CYCLE

       B_D = LeftState_VX(Bx_:B_+nDim,iFaceOut,j,k)

       DeltaBDotFA = (CorrectedFlux_VXB(BnL_,j,k,iFaceIn,iBlock) - &
            sum(B_D*FaceArea_D))/FaceArea2

       LeftState_VX(Bx_:B_+nDim,iFaceOut,j,k) = B_D + DeltaBDotFA*FaceArea_D

       B_D = RightState_VX(Bx_:B_+nDim,iFaceOut,j,k)

       DeltaBDotFA = (CorrectedFlux_VXB(BnR_,j,k,iFaceIn,iBlock) - &
            sum(B_D*FaceArea_D))/FaceArea2

       RightState_VX(Bx_:B_+nDim,iFaceOut,j,k) = B_D + DeltaBDotFA*FaceArea_D
    end do; end do

  end subroutine apply_bn_face_i

  !==========================================================================
  subroutine apply_bn_face_j(jFaceIn, jFaceOut, iBlock)

    integer, intent(in):: jFaceIn, jFaceOut, iBlock

    integer:: i, k
    real:: B_D(nDim), FaceArea_D(nDim)
    real:: FaceArea2, DeltaBDotFA
    !------------------------------------------------------------------------

    do k=1,nK; do i=1,nI
       if(.not.all(true_cell(i,jFaceOut-1:jFaceOut,k,iBlock)))CYCLE

       FaceArea_D = FaceNormal_DDFB(:,2,i,jFaceOut,k,iBlock)
       FaceArea2  = sum(FaceArea_D**2)

       if(FaceArea2 == 0.0) CYCLE

       B_D = LeftState_VY(Bx_:B_+nDim,i,jFaceOut,k)

       DeltaBDotFA = (CorrectedFlux_VYB(BnL_,i,k,jFaceIn,iBlock) - &
            sum(B_D*FaceArea_D))/FaceArea2

       LeftState_VY(Bx_:B_+nDim,i,jFaceOut,k) = B_D + DeltaBDotFA*FaceArea_D

       B_D = RightState_VY(Bx_:B_+nDim,i,jFaceOut,k)

       DeltaBDotFA = (CorrectedFlux_VYB(BnR_,i,k,jFaceIn,iBlock) - &
            sum(B_D*FaceArea_D))/FaceArea2

       RightState_VY(Bx_:B_+nDim,i,jFaceOut,k) = B_D + DeltaBDotFA*FaceArea_D

    end do; end do

  end subroutine apply_bn_face_j

  !==========================================================================

  subroutine apply_bn_face_k(kFaceIn, kFaceOut, iBlock)

    integer, intent(in):: kFaceIn, kFaceOut, iBlock

    integer:: i,j
    real:: B_D(nDim), FaceArea_D(nDim)
    real:: FaceArea2, DeltaBDotFA
    !------------------------------------------------------------------------
    do j=1,nJ; do i=1,nI
       if(.not.all(true_cell(i,j,kFaceOut-1:kFaceOut,iBlock)))CYCLE

       FaceArea_D = FaceNormal_DDFB(:,3,i,j,kFaceOut,iBlock)
       FaceArea2  = sum(FaceArea_D**2)

       if(FaceArea2 == 0.0) CYCLE

       B_D = LeftState_VZ(Bx_:B_+nDim,i,j,kFaceOut)

       DeltaBDotFA = ( CorrectedFlux_VZB(BnL_,i,j,kFaceIn,iBlock) - &
            sum(B_D*FaceArea_D))/FaceArea2

       LeftState_VZ(Bx_:B_+nDim,i,j,kFaceOut) = B_D + DeltaBDotFA*FaceArea_D  

       B_D = RightState_VZ(Bx_:B_+nDim,i,j,kFaceOut)

       DeltaBDotFA = (CorrectedFlux_VZB(BnR_,i,j,kFaceIn,iBlock) - &
            sum(B_D*FaceArea_D))/FaceArea2

       RightState_VZ(Bx_:B_+nDim,i,j,kFaceOut) = B_D + DeltaBDotFA*FaceArea_D  

    end do; end do

  end subroutine apply_bn_face_k

end module ModConserveFlux
