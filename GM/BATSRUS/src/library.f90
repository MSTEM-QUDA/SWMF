!^CFG COPYRIGHT UM
!==== Simple subroutines and functions that operate on all used blocks ========
!^CFG IF PROJECTION BEGIN
subroutine set_BLK(qa,qb)

  ! Set qa=qb for all used blocks, where qb is a scalar

  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModGeometry, ONLY : true_BLK,true_cell
  implicit none

  ! Arguments

  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK), intent(out) :: qa
  real, intent(in) :: qb

  ! Local variables:
  integer:: iBLK

  !---------------------------------------------------------------------------

  do iBLK=1,nBlockMax
     if(.not.unusedBLK(iBLK)) then
        if(true_BLK(iBLK))then
           qa(1:nI,1:nJ,1:nK,iBLK)=qb
        else
           where(true_cell(1:nI,1:nJ,1:nK,iBLK)) &
                qa(1:nI,1:nJ,1:nK,iBLK)=qb
        end if
     end if
  end do

end subroutine set_BLK

!=============================================================================
subroutine eq_BLK(qa,qb)

  ! Do qa=qb for all used blocks

  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModGeometry, ONLY : true_BLK,true_cell
  implicit none

  ! Arguments

  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK):: qa,qb
  intent(out) :: qa
  intent(in)  :: qb

  ! Local variables:
  integer:: iBLK

  !---------------------------------------------------------------------------

  do iBLK=1,nBlockMax
     if(.not.unusedBLK(iBLK)) then
        if(true_BLK(iBLK))then
           qa(1:nI,1:nJ,1:nK,iBLK)= qb(1:nI,1:nJ,1:nK,iBLK)
        else
           where(true_cell(1:nI,1:nJ,1:nK,iBLK)) &
                qa(1:nI,1:nJ,1:nK,iBLK)= qb(1:nI,1:nJ,1:nK,iBLK)
        end if

     end if
  end do

end subroutine eq_BLK

!=============================================================================
subroutine add_BLK(qa,qb)

  ! Do qa=qa+qb for all used blocks

  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModGeometry, ONLY : true_BLK,true_cell
  implicit none

  ! Arguments

  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK) :: qa, qb
  intent(inout) :: qa
  intent(in)    :: qb

  ! Local variables:
  integer:: iBLK

  !---------------------------------------------------------------------------

  do iBLK=1,nBlockMax
     if(.not.unusedBLK(iBLK)) then
        if(true_BLK(iBLK))then
           qa(1:nI,1:nJ,1:nK,iBLK)= &
                qa(1:nI,1:nJ,1:nK,iBLK)+qb(1:nI,1:nJ,1:nK,iBLK)
        else
           where(true_cell(1:nI,1:nJ,1:nK,iBLK)) &
                qa(1:nI,1:nJ,1:nK,iBLK)= &
                qa(1:nI,1:nJ,1:nK,iBLK)+qb(1:nI,1:nJ,1:nK,iBLK)
        end if
     end if
  end do

end subroutine add_BLK

!=============================================================================
subroutine sub_BLK(qa,qb)

  ! Do qa=qa-qb for all used blocks

  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModGeometry, ONLY : true_BLK,true_cell
  implicit none

  ! Arguments

  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK) :: qa, qb
  intent(inout) :: qa
  intent(in)    :: qb

  ! Local variables:
  integer:: iBLK

  !---------------------------------------------------------------------------

  do iBLK=1,nBlockMax
     if(.not.unusedBLK(iBLK)) then
        if(true_BLK(iBLK))then
           qa(1:nI,1:nJ,1:nK,iBLK)= &
                qa(1:nI,1:nJ,1:nK,iBLK)-qb(1:nI,1:nJ,1:nK,iBLK)
        else
           where(true_cell(1:nI,1:nJ,1:nK,iBLK)) &
                qa(1:nI,1:nJ,1:nK,iBLK)= &
                qa(1:nI,1:nJ,1:nK,iBLK)-qb(1:nI,1:nJ,1:nK,iBLK)
        end if
     end if
  end do

end subroutine sub_BLK

!=============================================================================
subroutine eq_plus_BLK(qa,qb,qc)

  ! Do qa=qb+qc for all used blocks

  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModGeometry, ONLY : true_BLK,true_cell
  implicit none

  ! Arguments

  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK) :: qa,qb,qc
  intent(out) :: qa
  intent(in)  :: qb,qc

  ! Local variables:
  integer:: iBLK

  !---------------------------------------------------------------------------

  do iBLK=1,nBlockMax
     if(.not.unusedBLK(iBLK)) then
        if(true_BLK(iBLK))then
           qa(1:nI,1:nJ,1:nK,iBLK)= &
                qb(1:nI,1:nJ,1:nK,iBLK)+qc(1:nI,1:nJ,1:nK,iBLK)
        else
           where(true_cell(1:nI,1:nJ,1:nK,iBLK)) &
                qa(1:nI,1:nJ,1:nK,iBLK)= &
                qb(1:nI,1:nJ,1:nK,iBLK)+qc(1:nI,1:nJ,1:nK,iBLK)
        end if
     end if
  end do


end subroutine eq_plus_BLK

!=============================================================================
subroutine add_times_BLK(qa,qb,qc)

  ! Do qa=qa+qb*qc for all used blocks, where qb is a scalar

  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModGeometry, ONLY : true_BLK,true_cell
  implicit none

  ! Arguments

  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK) :: qa,qc
  intent(inout) :: qa
  intent(in)    :: qc

  real, intent(in) :: qb

  ! Local variables:
  integer:: iBLK

  !---------------------------------------------------------------------------

  do iBLK=1,nBlockMax
     if(.not.unusedBLK(iBLK)) then
        if(true_BLK(iBLK))then
           qa(1:nI,1:nJ,1:nK,iBLK)= &
                qa(1:nI,1:nJ,1:nK,iBLK)+qb*qc(1:nI,1:nJ,1:nK,iBLK)
        else
           where(true_cell(1:nI,1:nJ,1:nK,iBLK)) &
                qa(1:nI,1:nJ,1:nK,iBLK)= &
                qa(1:nI,1:nJ,1:nK,iBLK)+qb*qc(1:nI,1:nJ,1:nK,iBLK)
        end if
     end if
  end do


end subroutine add_times_BLK

!=============================================================================
subroutine eq_plus_times_BLK(qa,qb,qc,qd)

  ! Do qa=qb+qc*qd for all used blocks, where qc is a scalar

  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModGeometry, ONLY : true_BLK,true_cell
  implicit none

  ! Arguments

  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK) :: qa,qb,qd
  intent(inout) :: qa
  intent(in)    :: qb
  intent(inout) :: qd

  real, intent(in) :: qc

  ! Local variables:
  integer:: iBLK

  !---------------------------------------------------------------------------

  do iBLK=1,nBlockMax
     if(.not.unusedBLK(iBLK)) then
        if(true_BLK(iBLK))then
           qa(1:nI,1:nJ,1:nK,iBLK)= &
                qb(1:nI,1:nJ,1:nK,iBLK)+qc*qd(1:nI,1:nJ,1:nK,iBLK)
        else
           where(true_cell(1:nI,1:nJ,1:nK,iBLK)) &
                qa(1:nI,1:nJ,1:nK,iBLK)= &
                qb(1:nI,1:nJ,1:nK,iBLK)+qc*qd(1:nI,1:nJ,1:nK,iBLK)
        end if
     end if
  end do

end subroutine eq_plus_times_BLK

!=============================================================================
real function dot_product_BLK(qa,qb)

  ! Return qa.qb=sum(qa*qb) for all used blocks

  use ModProcMH
  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModGeometry, ONLY : true_BLK,true_cell
  use ModMpi
  implicit none

  ! Arguments

  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK), intent(in) :: qa,qb

  ! Local variables:
  real    :: qproduct, qproduct_all
  integer :: iBLK, iError

  logical :: oktest, oktest_me

  !---------------------------------------------------------------------------

  call set_oktest('dot_product_BLK',oktest, oktest_me)

  qproduct=0.0

  do iBLK=1,nBlockMax
     if(.not.unusedBLK(iBLK)) then
        if(true_BLK(iBLK)) then
           qproduct=qproduct + &
                sum(qa(1:nI,1:nJ,1:nK,iBLK)*qb(1:nI,1:nJ,1:nK,iBLK))
        else
           qproduct=qproduct + &
                sum(qa(1:nI,1:nJ,1:nK,iBLK)*qb(1:nI,1:nJ,1:nK,iBLK),&
                MASK=true_cell(1:nI,1:nJ,1:nK,iBLK))
        end if
     end if
  end do

  if(nProc>1)then
     call MPI_allreduce(qproduct, qproduct_all, 1,  MPI_REAL, MPI_SUM, &
          iComm, iError)
     dot_product_BLK=qproduct_all
     if(oktest)write(*,*)'me,product,product_all:',&
          iProc,qproduct,qproduct_all
  else
     dot_product_BLK=qproduct
     if(oktest)write(*,*)'me,qproduct:',iProc,qproduct
  end if

end function dot_product_BLK

!=============================================================================
real function sum_BLK(qnum,qa)

  ! Return sum(qa) for all used blocks and true cells
  ! Do for each processor separately if qnum=1, otherwise add them all

  use ModProcMH
  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModGeometry, ONLY : true_BLK,true_cell
  use ModMpi
  implicit none

  ! Arguments

  integer, intent(in) :: qnum
  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK), intent(in) :: qa

  ! Local variables:
  real    :: qsum, qsum_all
  integer :: iBLK, iError

  logical :: oktest, oktest_me

  !---------------------------------------------------------------------------

  call set_oktest('sum_BLK',oktest, oktest_me)

  qsum=0.0

  do iBLK=1,nBlockMax
     if(.not.unusedBLK(iBLK)) then
        if(true_BLK(iBLK)) then
           qsum=qsum + sum(qa(1:nI,1:nJ,1:nK,iBLK))
        else
           qsum=qsum + sum(qa(1:nI,1:nJ,1:nK,iBLK), &
                MASK=true_cell(1:nI,1:nJ,1:nK,iBLK))
        end if
     end if
  end do

  if(qnum>1)then
     call MPI_allreduce(qsum, qsum_all, 1,  MPI_REAL, MPI_SUM, &
          iComm, iError)
     sum_BLK=qsum_all
     if(oktest)write(*,*)'me,sum,sum_all:',iProc,qsum,qsum_all
  else
     sum_BLK=qsum
     if(oktest)write(*,*)'me,qsum:',iProc,qsum
  end if

end function sum_BLK
!^CFG END PROJECTION
!=============================================================================
real function integrate_BLK(qnum,qa)               !^CFG IF CARTESIAN BEGIN

  ! Return the volume integral of qa, ie. sum(qa*cV_BLK) 
  ! for all used blocks and true cells
  ! Do for each processor separately if qnum=1, otherwise add them all

  use ModProcMH
  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModGeometry, ONLY :&
                          cV_BLK,&                   
                          true_BLK,true_cell
  use ModMpi
  implicit none 

  ! Arguments

  integer, intent(in) :: qnum
  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK), intent(in) :: qa

  ! Local variables:
  real    :: qsum, qsum_all
  integer :: iBLK, iError

  logical :: oktest, oktest_me

  !---------------------------------------------------------------------------

  call set_oktest('integrate_BLK',oktest, oktest_me)

  qsum=0.0
                                                     
  do iBLK=1,nBlockMax
     if(.not.unusedBLK(iBLK)) then
        if(true_BLK(iBLK)) then
           qsum=qsum + sum(qa(1:nI,1:nJ,1:nK,iBLK)*&
                cV_BLK(iBLK))
        else
           qsum=qsum + sum(qa(1:nI,1:nJ,1:nK,iBLK)*&
                cV_BLK(iBLK), &
                MASK=true_cell(1:nI,1:nJ,1:nK,iBLK))
        end if
     end if
  end do
                                                    
  if(qnum>1)then
     call MPI_allreduce(qsum, qsum_all, 1,  MPI_REAL, MPI_SUM, &
          iComm, iError)
     integrate_BLK=qsum_all
     if(oktest)write(*,*)'me,sum,sum_all:',iProc,qsum,qsum_all
  else
     integrate_BLK=qsum
     if(oktest)write(*,*)'me,qsum:',iProc,qsum
  end if

end function integrate_BLK    

subroutine integrate_cell_centered_vars(StateIntegral_V)
  use ModProcMH
  use ModAdvance,ONLY : State_VGB,tmp2_BLK
  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModVarIndexes,ONLY:nVar,P_
  use ModGeometry, ONLY :&
                          cV_BLK,&                   
                          true_BLK,true_cell
  use ModNumConst
  use ModMpi
  implicit none 

  ! Arguments

  real,dimension( nVar),intent(out) :: &
       StateIntegral_V

  ! Local variables:
  real ,dimension( nVar)   :: Sum_V, TotalSum_V
  integer :: iBLK, iError,iVar

  logical :: oktest, oktest_me

  !---------------------------------------------------------------------------

  call set_oktest('integrate_BLK',oktest, oktest_me)

  Sum_V=cZero
                                                     
  do iBLK=1,nBlockMax
     if(.not.unusedBLK(iBLK)) then
        if(true_BLK(iBLK)) then
           do iVar=1,nVar
              Sum_V(iVar)=Sum_V(iVar) + sum(&
              State_VGB(iVar,1:nI,1:nJ,1:nK,iBLK))*&
                cV_BLK(iBLK)
           end do
        else
           do iVar=1,nVar
              Sum_V(iVar)=Sum_V(iVar) + sum(&
              State_VGB(iVar,1:nI,1:nJ,1:nK,iBLK),&
              MASK=true_cell(1:nI,1:nJ,1:nK,iBLK))*cV_BLK(iBLK)
           end do
        end if
        tmp2_BLK(1:nI,1:nJ,1:nK,iBLK) = &
             State_VGB(P_,1:nI,1:nJ,1:nK,iBLK)
     end if
  end do

  if(nProc>1)then
     call MPI_allreduce(Sum_V, TotalSum_V, &
          nVar,  MPI_REAL, MPI_SUM, &
          iComm, iError)
   
     StateIntegral_V=TotalSum_V
  else
     StateIntegral_V=Sum_V
  end if
end subroutine integrate_cell_centered_vars
!^CFG END CARTESIAN

!=============================================================================

real function minval_BLK(qnum,qa)

  ! Return minval(qa)) corresponding to all used blocks
  ! If qnum<=1, return minval for the processor, otherwise
  ! return the minimum for all processors.

  use ModProcMH
  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModGeometry, ONLY : true_BLK,true_cell
  use ModMpi
  implicit none

  ! Arguments

  integer, intent(in) :: qnum

  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK), intent(in) :: qa

  ! Local variables:
  real    :: qminval, qminval_all
  integer :: iBLK, iError

  logical :: oktest, oktest_me

  !---------------------------------------------------------------------------

  call set_oktest('minval_BLK',oktest, oktest_me)

  qminval=1.e+30

  do iBLK=1,nBlockMax
     if(.not.unusedBLK(iBLK)) then
        if(true_BLK(iBLK)) then
           qminval=min(qminval, minval(qa(1:nI,1:nJ,1:nK,iBLK)))
        else
           qminval=min(qminval, minval(qa(1:nI,1:nJ,1:nK,iBLK),&
                MASK=true_cell(1:nI,1:nJ,1:nK,iBLK)))
        endif
     end if
  end do

  if(qnum>1)then
     call MPI_allreduce(qminval, qminval_all, 1,  MPI_REAL, MPI_MIN, &
          iComm, iError)
     minval_BLK=qminval_all
     if(oktest)write(*,*)'me,minval,minval_all:',iProc,qminval,qminval_all
!     if(qminval_all>=1.e+30)call stop_mpi('Error in minval_BLK: huge min!')
  else
     minval_BLK=qminval
     if(oktest)write(*,*)'me,qminval:',iProc,qminval
!     if(qminval>=1.e+30)call stop_mpi('Error in minval_BLK: huge min!')
  endif

end function minval_BLK

!=============================================================================

real function maxval_BLK(qnum,qa)

  ! Return maxval(qa)) corresponding to all used blocks
  ! If qnum<=1, return maxval for the processor, otherwise
  ! return the maximum for all processors.

  use ModProcMH
  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModGeometry, ONLY : true_BLK,true_cell
  use ModMpi
  implicit none

  ! Arguments

  integer, intent(in) :: qnum

  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK), intent(in) :: qa

  ! Local variables:
  real    :: qmaxval, qmaxval_all
  integer :: iBLK, iError

  logical :: oktest, oktest_me

  !---------------------------------------------------------------------------

  call set_oktest('maxval_BLK',oktest, oktest_me)

  qmaxval=-1.e+30

  do iBLK=1,nBlockMax
     if(.not.unusedBLK(iBLK)) then
        if(true_BLK(iBLK)) then
           qmaxval=max(qmaxval, maxval(qa(1:nI,1:nJ,1:nK,iBLK)))
        else
           qmaxval=max(qmaxval, maxval(qa(1:nI,1:nJ,1:nK,iBLK),&
                MASK=true_cell(1:nI,1:nJ,1:nK,iBLK)))
        endif
     end if
  end do

  if(qnum>1)then
     call MPI_allreduce(qmaxval, qmaxval_all, 1,  MPI_REAL, MPI_MAX, &
          iComm, iError)
     maxval_BLK=qmaxval_all
     if(oktest)write(*,*)'me,maxval,maxval_all:',iProc,qmaxval,qmaxval_all
     if(qmaxval_all<=-1.e+30)call stop_mpi('Error in maxval_BLK: tiny max!')
  else
     maxval_BLK=qmaxval
     if(oktest)write(*,*)'qmaxval:',qmaxval
     if(qmaxval<=-1.e+30)call stop_mpi('Error in maxval_BLK: tiny max!')
  endif

end function maxval_BLK

!=============================================================================
real function maxval_loc_BLK(qnum,qa,loc)

  ! Return maxval(qa)) corresponding to all used blocks and 
  ! also return the location of the maximum value into loc(5)=I,J,K,IBLK,PE
  ! If qnum<=1, return maxval for the processor, otherwise
  ! return the maximum for all processors.

  use ModProcMH
  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModGeometry, ONLY : true_BLK,true_cell
  use ModMpi
  implicit none

  ! Arguments

  integer, intent(in) :: qnum

  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK), intent(in) :: qa

  integer, intent(out):: loc(5)

  ! Local variables:
  real    :: qmaxval, qmaxval_all
  integer :: i,j,k,iBLK, iError

  real, external :: maxval_BLK

  logical :: oktest, oktest_me

  !---------------------------------------------------------------------------

  call set_oktest('maxval_loc_BLK',oktest, oktest_me)

  qmaxval=maxval_BLK(1,qa)
  if(qnum==1)then
     qmaxval_all=qmaxval
  else
     call MPI_allreduce(qmaxval, qmaxval_all, 1,  MPI_REAL, MPI_MAX, &
          iComm, iError)
  end if

  loc=-1
  if (qmaxval == qmaxval_all) then
     BLKLOOP: do iBLK=1,nBlockMax
        if(unusedBLK(iBLK)) CYCLE
        do k=1,nK; do j=1,nJ; do i=1,nI
           if(.not.true_cell(i,j,k,iBLK)) CYCLE
           if(qa(i,j,k,iBLK)==qmaxval)then
              loc(1)=i; loc(2)=j; loc(3)=k; loc(4)=iBLK; loc(5)=iProc
              EXIT BLKLOOP
           end if
        enddo; enddo; enddo; 
     enddo BLKLOOP
  end if

  maxval_loc_BLK=qmaxval_all

end function maxval_loc_BLK
!=============================================================================
real function maxval_loc_abs_BLK(qnum,qa,loc)

  ! Return maxval(abs(qa)) corresponding to all used blocks and 
  ! also return the location of the maximum value into loc(5)=I,J,K,IBLK,PE
  ! If qnum<=1, return maxval for the processor, otherwise
  ! return the maximum for all processors.

  use ModProcMH
  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModGeometry, ONLY : true_cell
  use ModMpi
  implicit none

  ! Arguments

  integer, intent(in) :: qnum

  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK), intent(in) :: qa

  integer, intent(out):: loc(5)

  ! Local variables:
  real    :: qmaxval, qmaxval_all
  integer :: i,j,k,iBLK, iError

  real, external :: maxval_abs_BLK

  logical :: oktest, oktest_me

  !---------------------------------------------------------------------------

  call set_oktest('maxval_loc_abs_BLK',oktest, oktest_me)

  qmaxval=maxval_abs_BLK(1,qa)
  if(qnum==1)then
     qmaxval_all=qmaxval
  else
     call MPI_allreduce(qmaxval, qmaxval_all, 1,  MPI_REAL, MPI_MAX, &
          iComm, iError)
  end if

  loc=-1
  if (qmaxval == qmaxval_all) then
     BLKLOOP: do iBLK=1,nBlockMax
        if(unusedBLK(iBLK)) CYCLE
        do k=1,nK; do j=1,nJ; do i=1,nI
           if(.not.true_cell(i,j,k,iBLK)) CYCLE
           if(abs(qa(i,j,k,iBLK))==qmaxval)then
              loc(1)=i; loc(2)=j; loc(3)=k; loc(4)=iBLK; loc(5)=iProc
              EXIT BLKLOOP
           end if
        enddo; enddo; enddo; 
     enddo BLKLOOP
  end if

  maxval_loc_abs_BLK=qmaxval_all

end function maxval_loc_abs_BLK
!=============================================================================
real function minval_loc_BLK(qnum,qa,loc)

  ! Return minval(qa)) corresponding to all used blocks and 
  ! also return the location of the minimum value into loc(5)=I,J,K,IBLK,PE
  ! If qnum<=1, return minval for the processor, otherwise
  ! return the minimum for all processors.

  use ModProcMH
  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModGeometry, ONLY : true_cell
  use ModMpi
  implicit none

  ! Arguments

  integer, intent(in) :: qnum

  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK), intent(in) :: qa

  integer, intent(out):: loc(5)

  ! Local variables:
  real    :: qminval, qminval_all
  integer :: i,j,k,iBLK, iError

  real, external :: minval_BLK

  logical :: oktest, oktest_me

  !---------------------------------------------------------------------------

  call set_oktest('minval_loc_BLK',oktest, oktest_me)

  qminval=minval_BLK(1,qa)
  if(qnum==1)then
     qminval_all=qminval
  else
     call MPI_allreduce(qminval, qminval_all, 1,  MPI_REAL, MPI_MIN, &
          iComm, iError)
  end if

  loc=-1
  if (qminval == qminval_all) then
     BLKLOOP:do iBLK=1,nBlockMax
        if(unusedBLK(iBLK)) CYCLE
        do k=1,nK; do j=1,nJ; do i=1,nI
           if(.not.true_cell(i,j,k,iBLK)) CYCLE
           if(qa(i,j,k,iBLK)==qminval)then
              loc(1)=i; loc(2)=j; loc(3)=k; loc(4)=iBLK; loc(5)=iProc
              EXIT BLKLOOP
           end if
        enddo; enddo; enddo; 
     enddo BLKLOOP
  end if

  minval_loc_BLK=qminval_all

end function minval_loc_BLK

!=============================================================================

real function maxval_abs_BLK(qnum,qa)

  ! Return maxval(abs(qa)) corresponding to all used blocks
  ! If qnum<=1, return maxval(abs(qa)) for the processor, otherwise
  ! return the maximum for all processors.

  use ModProcMH
  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModGeometry, ONLY : true_cell,true_BLK
  use ModMpi
  implicit none

  ! Arguments

  integer, intent(in) :: qnum

  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK), intent(in) :: qa

  ! Local variables:
  real    :: qmaxval, qmaxval_all
  integer :: iBLK, iError

  logical :: oktest, oktest_me

  !---------------------------------------------------------------------------

  call set_oktest('maxval_abs_BLK',oktest, oktest_me)

  qmaxval=-1.0

  do iBLK=1,nBlockMax
     if(.not.unusedBLK(iBLK)) then
        if(true_BLK(iBLK)) then
           qmaxval=max(qmaxval, maxval(abs(qa(1:nI,1:nJ,1:nK,iBLK))))
        else
           qmaxval=max(qmaxval, maxval(abs(qa(1:nI,1:nJ,1:nK,iBLK)),&
                MASK=true_cell(1:nI,1:nJ,1:nK,iBLK)))
        endif
     end if
  end do

  if(qnum>1)then
     call MPI_allreduce(qmaxval, qmaxval_all, 1,  MPI_REAL, MPI_MAX, &
          iComm, iError)
     maxval_abs_BLK=qmaxval_all
     if(oktest)write(*,*)'me,maxval,maxval_all:',iProc,qmaxval,qmaxval_all
     if(qmaxval_all<0.0) then
        call barrier_mpi
        call stop_mpi('Error in maxval_abs_BLK: negative max!')
     end if
  else
     maxval_abs_BLK=qmaxval
     if(oktest)write(*,*)'qmaxval:',qmaxval
     if(qmaxval<0.0)call stop_mpi('Error in maxval_abs_BLK: negative max!')
  endif

end function maxval_abs_BLK

!=============================================================================

real function maxval_abs_ALL(qnum,qa)

  ! Return maxval(abs(qa)) corresponding to all used blocks
  ! Include ghost cells and .not.true_cell -s too.
  ! If qnum<=1, return maxval(abs(qa)) for the processor, otherwise
  ! return the minimum for all processors.

  use ModProcMH
  use ModMain, ONLY : nI,nJ,nK,nBLK,nBlockMax,unusedBLK
  use ModMpi
  implicit none

  ! Arguments

  integer, intent(in) :: qnum

  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2,nBLK), &
       intent(in) :: qa

  ! Local variables:
  real    :: qmaxval, qmaxval_all
  integer :: iBLK, iError

  logical :: oktest, oktest_me

  !---------------------------------------------------------------------------

  call set_oktest('maxval_abs_ALL',oktest, oktest_me)

  qmaxval=-1.0

  do iBLK=1,nBlockMax
     if(.not.unusedBLK(iBLK)) then
        qmaxval=max(qmaxval, maxval(abs(qa(:,:,:,iBLK))))
     end if
  end do

  if(qnum>1)then
     call MPI_allreduce(qmaxval, qmaxval_all, 1,  MPI_REAL, MPI_MAX, &
          iComm, iError)
     maxval_abs_ALL=qmaxval_all
     if(oktest)write(*,*)'me,maxval,maxval_all:',iProc,qmaxval,qmaxval_all
  else
     maxval_abs_ALL=qmaxval
     if(oktest)write(*,*)'qmaxval:',qmaxval
  endif

end function maxval_abs_ALL

!=============================================================================
real function test_cell_value(qa,Imin,Imax,Jmin,Jmax,Kmin,Kmax)

  ! Find the value at the test cell location Itest, Jtest, Ktest,BLKtest
  ! PROCtest and then broadcast it to all PROC.

  use ModProcMH
  use ModMain, ONLY : nBLK,PROCtest,Itest,Jtest,Ktest,BLKtest
  use ModMpi
  implicit none

  ! Arguments

  integer, intent(in) :: Imin,Imax,Jmin,Jmax,Kmin,Kmax
  real, dimension(Imin:Imax,Jmin:Jmax,Kmin:Kmax,nBLK), &
       intent(in) :: qa

  ! Local variables:
  integer :: iError
  real    :: qval

  logical :: oktest, oktest_me

  !---------------------------------------------------------------------------

  call set_oktest('test_cell_value',oktest, oktest_me)

  qval=0.0

  if (PROCtest == iProc) qval = qa(Itest,Jtest,Ktest,BLKtest)

  call MPI_Bcast(qval,1,MPI_REAL,PROCtest,iComm,iError)

  test_cell_value=qval

  if(oktest)write(*,*)'i,j,k,BLK,PROC,qval:',Itest,Jtest,Ktest,BLKtest, &
       PROCtest,qval

end function test_cell_value

!=============================================================================

subroutine xyz_to_spherical(xFace,yFace,zFace,rFace,phiFace,ThetaFace)

  use ModNumConst
  implicit none

  real, intent(in)  :: xFace,yFace,zFace
  real, intent(out) :: rFace,thetaFace,phiFace


  rFace = sqrt(xFace**2 + yFace**2 + zFace**2)

  ! get the phi(lonitude relative to +x) and 
  ! theta (co-latitude) position of the face
  if (XFace == cZero .and. YFace == cZero) then
     PhiFace = cZero
  else
     PhiFace = atan2(YFace/RFace, XFace/RFace)
  end if
  if (PhiFace < cZero) PhiFace = PhiFace + cTwoPi
  ThetaFace = acos(zFace/RFace)

end subroutine xyz_to_spherical

!=============================================================================

subroutine set_oktest(str,oktest,oktest_me)

  use ModProcMH
  use ModMain, ONLY : iteration_number,Ttest,iterTEST,PROCtest,lVerbose, &
       time_accurate,time_simulation,test_string
  implicit none

  character (len=*) :: str
  integer, external :: index_mine
  logical :: oktest, oktest_me
  !----------------------------------------------------------------------------

  if(iteration_number>iterTEST .or. &
       (time_accurate .and. time_simulation>Ttest))then
     oktest=index_mine(' '//test_string,' '//str//' ')>0
     oktest_me = oktest .and. iProc==PROCtest
     if(oktest_me)then
        write(*,*)str,' at iter=',iteration_number
     else if(lVerbose>=100)then
        write(*,*)str,' CALLED by me=',iProc,' at iter=',iteration_number
     else if(iProc==PROCtest.and.lVerbose>=10)then
        write(*,*)str,' CALLED at iter=',iteration_number
     endif
  else
     oktest    = .false.
     oktest_me = .false.
  end if

end subroutine set_oktest

!=============================================================================

integer function index_mine(str1,str2)

  implicit none

  character (len=*), intent(in) :: str1, str2

  index_mine=index(str1,str2)

end function index_mine

!=============================================================================

subroutine barrier_mpi

  use ModProcMH
  use ModMpi
  implicit none

  ! Local variables:
  integer :: iError

  !----------------------------------------------------------------------------

  call timing_start('barrier')
  call MPI_barrier(iComm, iError)
  call timing_stop('barrier')

end subroutine barrier_mpi

!=============================================================================

subroutine stop_mpi(str)

  use ModProcMH
  use ModMain, ONLY : iteration_number,NameThisComp,IsStandAlone
  use ModMpi
  implicit none

  character (len=*), intent(in) :: str

  ! Local variables:
  integer :: iError,nError

  !----------------------------------------------------------------------------

  if(IsStandAlone)then
     write(*,*)'Stopping execution! me=',iProc,' at iteration=',&
          iteration_number,' with msg:'
     write(*,*)str
     call MPI_abort(iComm, nError, iError)
     stop
  else
     write(*,*)NameThisComp,': stopping execution! me=',iProc,&
          ' at iteration=',iteration_number
     call CON_stop(NameThisComp//':'//str)
  end if

end subroutine stop_mpi



subroutine error_report(str,value,iErrorIn,show_first)

  use ModProcMH
  use ModMain, ONLY : iteration_number
  use ModIO, ONLY: write_myname
  use ModMpi
  implicit none

  ! Collect global error reports
  ! Reports are identified by an individual string str if iErrorIn<1
  !    and iErrorIn is set to a value > 1 for later use.
  ! If iErrorIn is > 1 to start with, it is used for error identification.
  ! Make statistics of errors based on value
  ! print statistics if str='PRINT'

  ! Parameters:

  ! Maximum number of different types of errors
  integer, parameter :: maxerror=100

  ! Arguments:

  character (LEN=*), intent(in) :: str
  real, intent(in)              :: value
  integer, intent(inout)        :: iErrorIn
  logical, intent(in)           :: show_first

  ! Local variables:

  integer :: iError

  ! Current number of different types of errors
  integer :: nErrors=0

  ! Message, number, occurance, and statistics of errors
  character (LEN=60), dimension(maxerror), save :: error_message
  integer, dimension(maxerror):: &
       error_count=0, error_count_sum, error_count_max,&
       iter_first=100000, iter_last=-1
  real,    dimension(maxerror):: &
       error_min=1e30, error_max=-1e30, &
       error_mean=0., error_last=0., error_last_sum

  character (LEN=60) :: msg

  integer,            dimension(:),   allocatable :: nErrors_all
  character (LEN=60), dimension(:,:), allocatable :: error_message_all
  integer,            dimension(:,:), allocatable :: &
       error_count_all, iter_first_all, iter_last_all
  real,               dimension(:,:), allocatable :: &
       error_min_all, error_max_all, error_mean_all, error_last_all

  integer :: i,i0,ip

  !--------------------------------------------------------------------------

  !Debug
  !write(*,*)'Error_report me, iErrorIn, value, str=',iProc,iErrorIn,value,str

  if(str=='PRINT')then
     ! Allocate memory in PROC 0
     allocate(&
          nErrors_all(nProc),&
          error_message_all(maxerror,nProc),&
          error_count_all(maxerror,nProc),&
          iter_first_all(maxerror,nProc),&
          iter_last_all(maxerror,nProc),&
          error_min_all(maxerror,nProc),&
          error_max_all(maxerror,nProc),&
          error_mean_all(maxerror,nProc),&
          error_last_all(maxerror,nProc))

     ! Collect the error reports
     call MPI_gather(nErrors, 1, MPI_INTEGER, &
          nErrors_all, 1, MPI_INTEGER, 0, iComm, iError)
     call MPI_gather(error_message, 60*maxerror, MPI_CHARACTER, &
          error_message_all, 60*maxerror, MPI_CHARACTER, 0, iComm,iError)
     call MPI_gather(error_count, maxerror, MPI_INTEGER, &
          error_count_all, maxerror, MPI_INTEGER, 0, iComm, iError)
     call MPI_gather(iter_first, maxerror, MPI_INTEGER, &
          iter_first_all, maxerror, MPI_INTEGER, 0, iComm, iError)
     call MPI_gather(iter_last, maxerror, MPI_INTEGER, &
          iter_last_all, maxerror, MPI_INTEGER, 0, iComm, iError)
     call MPI_gather(error_min, maxerror, MPI_REAL, &
          error_min_all, maxerror, MPI_REAL, 0, iComm, iError)
     call MPI_gather(error_max, maxerror, MPI_REAL, &
          error_max_all, maxerror, MPI_REAL, 0, iComm, iError)
     call MPI_gather(error_mean, maxerror, MPI_REAL, &
          error_mean_all, maxerror, MPI_REAL, 0, iComm, iError)
     call MPI_gather(error_last, maxerror, MPI_REAL, &
          error_last_all, maxerror, MPI_REAL, 0, iComm, iError)

     ! Analyze errors in PROC 0
     if(iProc==0)then
        nErrors=0
        do ip=1,nProc
           do i=1,nErrors_all(ip)
              msg=error_message_all(i,ip)
              i0=1
              do
                 if(i0>nErrors)then
                    nErrors=i0
                    error_message(i0)=msg
                    error_count_max(i0)=error_count_all(i,ip)
                    error_count_sum(i0)=error_count_all(i,ip)
                    iter_first(i0)=iter_first_all(i,ip)
                    iter_last(i0)=iter_last_all(i,ip)
                    error_min(i0)=error_min_all(i,ip)
                    error_max(i0)=error_max_all(i,ip)
                    error_mean(i0)=error_mean_all(i,ip)
                    error_last(i0)=error_last_all(i,ip)
                    error_last_sum(i0)=error_last_all(i,ip)
                    exit
                 end if
                 if(error_message(i0)==msg)then

                    error_mean(i0)=&
                         (error_mean_all(i,ip)*error_count_all(i,ip)+&
                         error_mean(i0)*error_count_sum(i0)) &
                         /(error_count_all(i,ip)+error_count_sum(i0))

                    if(iter_last(i0)<iter_last_all(i,ip))then
                       error_last(i0)=error_last_all(i,ip)
                       error_last_sum(i0)=error_last_all(i,ip)
                       iter_last(i0)=iter_last_all(i,ip)
                    elseif(iter_last(i0)==iter_last_all(i,ip))then
                       error_last_sum(i0)=error_last_sum(i0)+&
                            error_last_all(i,ip)
                    end if

                    error_count_sum(i0)=&
                         error_count_all(i,ip)+error_count_sum(i0)
                    error_count_max(i0)=&
                         max(error_count_all(i,ip),error_count_max(i0))
                    iter_first(i0)=&
                         min(iter_first_all(i,ip),iter_first(i0))
                    error_min(i0)=&
                         min(error_min_all(i,ip),error_min(i0))
                    error_max(i0)=&
                         max(error_max_all(i,ip),error_min(i0))
                    exit
                 end if
                 i0=i0+1
              end do ! i0
           end do ! error types
        end do ! processors

        ! Report errors
        if(nErrors==0)then
           call write_myname; write(*,*)'error report: no errors...'
        else
           do i=1,nErrors
              call write_myname
              write(*,'(a,a)')'Error_report for ',trim(error_message(i))
              call write_myname
              write(*,*)'OCCURED first=',iter_first(i),&
                   ' last=',iter_last(i),&
                   ' count_max=',error_count_max(i),&
                   ' count_sum=',error_count_sum(i)
              call write_myname
              write(*,*)'VALUES min=',error_min(i),' max=',error_max(i),&
                   ' mean=',error_mean(i),' last=',error_last(i),&
                   ' last_sum=',error_last_sum(i)
              call write_myname; write(*,*)
           end do
        end if

     end if ! iProc==0

     deallocate(nErrors_all,error_message_all,error_count_all,&
          iter_first_all,iter_last_all,error_min_all,error_max_all,&
          error_mean_all,error_last_all)

     return

  end if ! PRINT

  if(iErrorIn<1 .or. iErrorIn>nErrors) then
     ! Determine iErrorIn based on str
     iErrorIn=1
     do
        if(iErrorIn>nErrors)then
           ! First occurance of this error type
           nErrors=iErrorIn
           exit
        end if
        if(error_message(iErrorIn)==str)exit
        iErrorIn=iErrorIn+1
     end do
  end if

  i=iErrorIn

  error_count(i)=error_count(i)+1

  iter_last(i)=iteration_number
  error_last(i)=value

  if(error_count(i)==1)then
     if(show_first)then
        call write_myname;
        write(*,*)'First error for ',str,' (PE=',iProc,&
          ') at iter=',iteration_number,' with value=',value
     end if
     error_message(i)=str
     iter_first(i)=iteration_number
     error_min(i)=value
     error_max(i)=value
     error_mean(i)=value
  else
     error_min(i)=min(error_min(i),value)
     error_max(i)=max(error_max(i),value)
     error_mean(i)=(error_mean(i)*(error_count(i)-1)+value)/error_count(i)
  end if

end subroutine error_report

!==============================================================================

subroutine test_error_report

  use ModProcMH
  use ModMain, ONLY : iteration_number
  implicit none

  integer:: ierr1=-1, ierr2=-1, ierr3=-1

  ! Test error_report
  select case(iProc)
  case(0)
     iteration_number=1
     call error_report('negative pressure',-1.,ierr1,.true.)
     call error_report('negative pressure',-2.,ierr1,.true.)
     call error_report('energy correction',0.1,ierr2,.false.)
     iteration_number=2
     call error_report('energy correction',0.2,ierr2,.false.)
     iteration_number=3
     call error_report('negative pressure',-6.,ierr1,.true.)
     call error_report('only PE 0',100.,ierr3,.true.)
     call error_report('energy correction',0.6,ierr2,.false.)
  case(1)
     iteration_number=1
     call error_report('only PE 1',200.,ierr3,.true.)
     call error_report('energy correction',0.01,ierr2,.false.)
     iteration_number=2
     call error_report('energy correction',0.02,ierr2,.false.)
     iteration_number=3
     call error_report('energy correction',0.06,ierr2,.false.)
  end select

  call error_report('PRINT',0.,iErr1,.true.)

end subroutine test_error_report

!==============================================================================
subroutine split_str(str,nmax,strarr,n)

  implicit none

  character (len=*), intent(in):: str
  integer, intent(in) :: nmax
  character (len=10), intent(out):: strarr(nmax)
  integer, intent(out):: n

  character (len=100) :: s
  integer :: i,l

  !--------------------------------------------------------------------------

  n=0
  l=len_trim(str)
  s=str(1:l)

  do
     ! Check leading spaces
     i=1
     do while(s(i:i)==' ' .and. i<=l)
        i=i+1
     end do

     if(i>l) EXIT       ! All spaces

     if(i>1)s=s(i:l)   ! Delete leading spaces

     i=index(s,' ')     ! Find end of first word

     n=n+1              ! Put word into strarr
     strarr(n)=s(1:i-1)
     s=s(i+1:l)         ! Delete word and 1 space from string
     if(n==nmax)exit
  end do

end subroutine split_str
!==============================================================================

subroutine check_plot_range
  use ModGeometry, ONLY : XyzMin_D,XyzMax_D,nCells
  use ModParallel, ONLY : proc_dims
  use ModIO
  implicit none

  integer :: ifile, iBLK
  real :: dx, dy, dz, dxmax, dymax, dzmax, dsmall, r

  logical :: oktest,oktest_me
  !---------------------------------------------------------------------------

  call set_oktest('check_plot_range',oktest,oktest_me)

  if(oktest_me)write(*,*)&
       'Check_Plot_Range: x1,y1,z1,x2,y2,z2=',XyzMin_D,XyzMax_D

  dxmax=(XyzMax_D(1)-XyzMin_D(1))/(nCells(1)*proc_dims(1))
  dymax=(XyzMax_D(2)-XyzMin_D(2))/(nCells(2)*proc_dims(2))
  dzmax=(XyzMax_D(3)-XyzMin_D(3))/(nCells(3)*proc_dims(3))
  dsmall=dxmax*1.e-6

  if(oktest_me)write(*,*)'Check_Plot_Range: proc_dims,dxmax,dymax,dzmax=',&
       proc_dims,dxmax,dymax,dzmax

  do ifile=plot_+1,plot_+nplotfile
     if(index(plot_type(ifile),'sph')>0) CYCLE

     if(oktest_me)write(*,*)'For file ',ifile-plot_,&
          ' original range   =',plot_range(:,ifile)

     plot_range(1,ifile)=max(XyzMin_D(1),plot_range(1,ifile))
     plot_range(2,ifile)=min(XyzMax_D(1),plot_range(2,ifile))
     plot_range(3,ifile)=max(XyzMin_D(2),plot_range(3,ifile))
     plot_range(4,ifile)=min(XyzMax_D(2),plot_range(4,ifile))
     plot_range(5,ifile)=max(XyzMin_D(3),plot_range(5,ifile))
     plot_range(6,ifile)=min(XyzMax_D(3),plot_range(6,ifile))
     if(plot_dx(1,ifile)<=1.e-6)then
        ! No fixed resolution is required
        plot_dx(:,ifile)=plot_dx(1,ifile)
        if(oktest_me)write(*,*)'For file ',ifile-plot_,&
             ' adjusted range   =',plot_range(:,ifile)

        CYCLE
     end if

     ! Make sure that dx is a power of 2 fraction of dxmax

     dx=plot_dx(1,ifile)
     r=dxmax/dx
     r=2.0**nint(alog(r)/alog(2.))
     dx=dxmax/r
     dy=dymax/r
     dz=dzmax/r
     if(oktest_me)write(*,*)'For file ',ifile-plot_,&
          ' original dx      =',plot_dx(1,ifile)
     plot_dx(1,ifile)=dx
     plot_dx(2,ifile)=dy
     plot_dx(3,ifile)=dz
     if(oktest_me)write(*,*)'For file ',ifile-plot_,&
          ' adjusted dx,dy,dz=',plot_dx(:,ifile)

     ! Make sure that plotting range is placed at an integer multiple of dx

     if(plot_range(2,ifile)-plot_range(1,ifile)>1.5*dx)then
        plot_range(1,ifile)=XyzMin_D(1)+&
             nint((plot_range(1,ifile)-dsmall-XyzMin_D(1))/dx)*dx
        plot_range(2,ifile)=XyzMin_D(1)+&
             nint((plot_range(2,ifile)+dsmall-XyzMin_D(1))/dx)*dx
     endif
     if(plot_range(4,ifile)-plot_range(3,ifile)>1.5*dy)then
        plot_range(3,ifile)=XyzMin_D(2)+&
             nint((plot_range(3,ifile)-dsmall-XyzMin_D(2))/dy)*dy
        plot_range(4,ifile)=XyzMin_D(2)+&
             nint((plot_range(4,ifile)+dsmall-XyzMin_D(2))/dy)*dy
     endif
     if(plot_range(6,ifile)-plot_range(5,ifile)>1.5*dz)then
        plot_range(5,ifile)=XyzMin_D(3)+&
             nint((plot_range(5,ifile)-dsmall-XyzMin_D(3))/dz)*dz
        plot_range(6,ifile)=XyzMin_D(3)+&
             nint((plot_range(6,ifile)+dsmall-XyzMin_D(3))/dz)*dz
     endif
     if(oktest_me)write(*,*)'For file ',ifile-plot_,&
          ' adjusted range   =',plot_range(:,ifile)

  end do ! ifile

end subroutine check_plot_range

!==============================================================================
subroutine find_test_cell

  ! Find cell indices corresponding to Xtest, Ytest, Ztest coordinates
  ! or print out cell coordinates corresponding to Itest, Jtest, Ktest, ...

  use ModProcMH
  use ModMain
  use ModGeometry, ONLY : x_BLK,y_BLK,z_BLK,dx_BLK
  use ModParallel, ONLY : NOBLK, neiLEV,neiPE,neiBLK
  use ModAdvance, ONLY : tmp1_BLK
  use ModMpi
  implicit none

  real :: qdist, qdist_min
  logical :: pass_message
  integer :: loc(5), idir, iError, iProcTestMe
  real, external :: minval_loc_BLK
  !----------------------------------------------------------------------------

  pass_message = .false.

  if(.not.coord_test)then
     if(iProc==PROCtest)then
        if(1<=BLKtest.and.BLKtest<=nBlockMax)then
           if(unusedBLK(BLKtest))then
              write(*,*)'Test cell is in an unused block'
           else
              Xtest_mod = x_BLK(Itest,Jtest,Ktest,BLKtest)
              Ytest_mod = y_BLK(Itest,Jtest,Ktest,BLKtest)
              Ztest_mod = z_BLK(Itest,Jtest,Ktest,BLKtest)
              pass_message = .true.
           end if
        else
           write(*,*)'BLKtest=',BLKtest,' is out of 1..nBlockMax=',&
                nBlockMax
        end if
     end if
     call MPI_Bcast(pass_message,1,MPI_LOGICAL,PROCtest,iComm,iError)
     if (.not. pass_message) return

  else   ! if a coord_test

     pass_message = .true.

     tmp1_BLK(1:nI,1:nJ,1:nK,1:nBlockMax)=&
          abs(x_BLK(1:nI,1:nJ,1:nK,1:nBlockMax)-Xtest)+&
          abs(y_BLK(1:nI,1:nJ,1:nK,1:nBlockMax)-Ytest)+&
          abs(z_BLK(1:nI,1:nJ,1:nK,1:nBlockMax)-Ztest)

     qdist=minval_loc_BLK(nProc,tmp1_BLK,loc)

     !!! write(*,*)'minval=',qdist,' loc=',loc

     Itest=loc(1)
     Jtest=loc(2)
     Ktest=loc(3)
     BLKtest=loc(4)
     iProcTestMe=loc(5)

     ! Tell everyone which processor contains the test cell
     ! The others have -1 so MPI_MAX behaves like a broadcast.
     call MPI_allreduce(iProcTestMe,PROCtest,1,MPI_INTEGER,MPI_MAX,&
          iComm,iError)

     if(iProc==ProcTest)then
        Xtest_mod = x_BLK(Itest,Jtest,Ktest,BLKtest)
        Ytest_mod = y_BLK(Itest,Jtest,Ktest,BLKtest)
        Ztest_mod = z_BLK(Itest,Jtest,Ktest,BLKtest)
     end if
  end if

  if (pass_message) then

     call MPI_Bcast(Xtest_mod,1,MPI_REAL,PROCtest,iComm,iError)
     call MPI_Bcast(Ytest_mod,1,MPI_REAL,PROCtest,iComm,iError)
     call MPI_Bcast(Ztest_mod,1,MPI_REAL,PROCtest,iComm,iError)

     if(iProc==PROCtest .and. UseTestCell .and. lVerbose>0)then
        write(*,*)
        write(*,*)'Selected test cell:'
        write(*,'(a,i4,a,i4,a,i4,a,i8,a,i5)')&
             'I=',Itest,' J=',Jtest,' K=',Ktest,&
             ' BLK=',BLKtest,' PE=',PROCtest
        write(*,'(a,f12.5,a,f12.5,a,f12.5,a,f12.5)') &
             'x=',x_BLK(Itest,Jtest,Ktest,BLKtest),&
             ' y=',y_BLK(Itest,Jtest,Ktest,BLKtest),&
             ' z=',z_BLK(Itest,Jtest,Ktest,BLKtest),&
             ' dx=',dx_BLK(BLKtest)

  	do idir=1,6
  	   select case(neiLEV(idir,BLKtest))
           case(0,1)
              write(*,'(a,i2,a,i2,a,i5,a,i8)')&
                   'idir=',idir,' neiLEV=',neiLEV(idir,BLKtest),&
                   ' neiPE=',neiPE(1,idir,BLKtest),&
                   ' neiBLK=',neiBLK(1,idir,BLKtest)
           case(-1)
              write(*,'(a,i2,a,i2,a,4i5,a,4i8)')&
                   'idir=',idir,' neiLEV=',neiLEV(idir,BLKtest),&
                   ' neiPE=',neiPE(:,idir,BLKtest),&
                   ' neiBLK=',neiBLK(:,idir,BLKtest)
  	   case(NOBLK)
  	      write(*,'(a,i2,a,i5)')&
                   'idir=',idir,' neiLEV=',neiLEV(idir,BLKtest)
  	   end select
  	end do
  	write(*,*)

     end if

  end if

end subroutine find_test_cell
!========================================================================
!----------------------------------------------------------------------
subroutine xyz_to_peblk(x,y,z,iPe,iBlock,DoFindCell,iCell,jCell,kCell)
  !-The programm returns the value of iPE and iBlock for
  !the given Xyz values. If DoFindIjk=.true., 
  !the i,j,k values are returned too
  use ModParallel,ONLY : proc_dims
  use ModOctree, ONLY: adaptive_block_ptr, octree_roots
  use ModSize, ONLY: nCells
  use ModGeometry, ONLY : TypeGeometry         !^CFG IF NOT CARTESIAN
  use ModGeometry, ONLY : XyzMin_D, XyzMax_D
  use ModNumConst
  implicit none

  real, intent(in) :: x,y,z
  integer, intent(out) :: iPE,iBlock
  logical, intent(in) :: DoFindCell
  integer, intent(out):: iCell,jCell,kCell


  type(adaptive_block_ptr):: Octree
  real,dimension(3) :: Xyz_D,DXyz_D,XyzCorner_D,XyzCenter_D
  integer,dimension(3)::IjkRoot_D
  logical,dimension(3):: IsLowerThanCenter_D
  !----------------------------------------------------------------------

  nullify(Octree % ptr)

  ! Perform the coordinate transformation, if needed
  select case(TypeGeometry)           !^CFG IF NOT CARTESIAN
  case('cartesian')                   !^CFG IF NOT CARTESIAN
     Xyz_D(1)=x
     Xyz_D(2)=y
     Xyz_D(3)=z
  case('spherical')                   !^CFG IF NOT CARTESIAN BEGIN
     call xyz_to_spherical(x,y,z,Xyz_D(1),Xyz_D(2),Xyz_D(3))
  case('spherical_lnr')                   
     call xyz_to_spherical(x,y,z,Xyz_D(1),Xyz_D(2),Xyz_D(3))
     Xyz_D(1)=log(Xyz_D(1))
  case default
     call stop_mpi('Unknown TypeGeometry='//TypeGeometry)
  end select                          !^CFG END CARTESIAN

  !Check, if we are within the Octree:
  if(any(Xyz_D(1:3)<XyzMin_D(1:3)).or.any(Xyz_D(1:3)>XyzMax_D(1:3)-cTiny))&
       call stop_mpi(&
       'Xyz_to_peblk subroutine: the point is out of the Octree') 
  !Find the octree root

  DXyz_D=(XyzMax_D-XyzMin_D)/proc_dims
  IjkRoot_D=int((Xyz_D-XyzMin_D)/DXyz_D)
  XyzCorner_D=XyzMin_D+DXyz_D*IjkRoot_D

  Octree % ptr => &
       octree_roots(IjkRoot_D(1)+1,IjkRoot_D(2)+1,IjkRoot_D(3)+1) % ptr
  ! Recursive procedure to find the adaptive block:
  do
     if(Octree % ptr % used) then
        iPE    = octree % ptr % PE
        iBlock = octree % ptr % BLK
        if(DoFindCell)then
           DXyz_D=DXyz_D/nCells
           iCell=int((Xyz_D(1)-XyzCorner_D(1))/DXyz_D(1))+1
           jCell=int((Xyz_D(2)-XyzCorner_D(2))/DXyz_D(2))+1
           kCell=int((Xyz_D(3)-XyzCorner_D(3))/DXyz_D(3))+1
        end if
        EXIT
     else
        DXyz_D=cHalf*DXyz_D
        XyzCenter_D=XyzCorner_D+DXyz_D
        IsLowerThanCenter_D=Xyz_D<XyzCenter_D
        if(IsLowerThanCenter_D(2))then
           if(.not.IsLowerThanCenter_D(3))then
              XyzCorner_D(3)=XyzCenter_D(3)
              if(IsLowerThanCenter_D(1))then
                 Octree % ptr => Octree % ptr % child1
              else
                 XyzCorner_D(1)=XyzCenter_D(1)
                 Octree % ptr => Octree % ptr % child2
              end if
           else
              if(.not.IsLowerThanCenter_D(1))then
                 XyzCorner_D(1)=XyzCenter_D(1)
                 Octree % ptr => Octree % ptr % child3
              else
                 Octree % ptr => Octree % ptr % child4
              end if
           end if
        else
           XyzCorner_D(2)=XyzCenter_D(2)
           if(IsLowerThanCenter_D(3))then
              if(IsLowerThanCenter_D(1))then
                 Octree % ptr => Octree % ptr % child5
              else
                 XyzCorner_D(1)=XyzCenter_D(1)
                 Octree % ptr => Octree % ptr % child6
              end if
           else
              XyzCorner_D(3)=XyzCenter_D(3)
              if(.not.IsLowerThanCenter_D(1))then
                 XyzCorner_D(1)=XyzCenter_D(1)
                 Octree % ptr => Octree % ptr % child7
              else
                 Octree % ptr => Octree % ptr % child8
              end if
           end if
        end if
     end if
  end do
end subroutine xyz_to_peblk

!=========================================================================
subroutine get_date_time(iTime_I)
  
  use ModMain,        ONLY : StartTime, Time_Simulation
  use ModTimeConvert, ONLY : time_real_to_int

  implicit none
  integer, intent(out) :: iTime_I(7)

  call time_real_to_int(StartTime+Time_Simulation,iTime_I)

end subroutine get_date_time
!=========================================================================

subroutine get_time_string
  use ModMain, ONLY: StringTimeH4M2S2,Time_Simulation
  implicit none

  write(StringTimeH4M2S2,'(i4.4,i2.2i2.2)') &
       int(                            Time_Simulation/3600.), &
       int((Time_Simulation-(3600.*int(Time_Simulation/3600.)))/60.), &
       int( Time_Simulation-(  60.*int(Time_Simulation/  60.)))

end subroutine get_time_string

