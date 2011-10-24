!^CFG COPYRIGHT UM
!^CFG FILE IMPLICIT
subroutine impl_matvec(qx,qy,n)

  ! Calculate qy= L.qx = (I - beta*dt*dR/dw).qx
  ! Do it matrix-free or with the matrix or preconditioned depending 
  ! on JacobianType
  !
  ! N contains the number of elements in qx and qy.

  use ModImplicit
  use ModImplHypre, ONLY: hypre_preconditioner
  use ModMpi
  implicit none

  integer, intent(in):: n
  real, intent(in)   :: qx(n)
  real, intent(out)  :: qy(n)

  logical :: oktest, oktest_me
  !----------------------------------------------------------------------------

  call set_oktest('impl_matvec',oktest,oktest_me)

  call timing_start('impl_matvec')

  if(oktest_me.and.nImplBLK>0)&
       write(*,*)'matvec_impl initial n,sum(x**2),x(test)=',&
       n,sum(qx(1:n)**2),qx(implVARtest)

  nmatvec=nmatvec+1

  if(PrecondType == 'HYPRE')then
     call get_semi_impl_matvec(qx, qy, n)
     call hypre_preconditioner(n, qy)
  else
     select case(JacobianType)
     case('free')
        call impl_matvec_free(qx,qy,n)
     case('with')
        call impl_matvec_with(qx,qy,n)
     case('prec')
        call impl_matvec_prec(qx,qy,n)
     case default
        call stop_mpi('Unknown value for JacobianType')
     end select
  end if

  if(oktest_me.and.nImplBLK>0)&
       write(*,*)'impl_matvec final sum(x**2),sum(y**2),y(test)=',&
       sum(qx(1:n)**2),sum(qy(1:n)**2),qy(implVARtest)

  !DEBUG
  !write(*,*)'implVARtest,maxval,loc(abs(qy))=',&
  !     implVARtest,maxval(abs(qy)),maxloc(abs(qy))

  call timing_stop('impl_matvec')

end subroutine impl_matvec

!=============================================================================
subroutine impl_matvec_free(qx,qy,nn)

  ! Calculate qy=L.qx for the iterative solver, matrix-free 
  ! where L= I - beta*dt*dR/dw   (dt=dt_implicit)
  !
  ! One sided derivative:
  !----------------------
  ! ImplEps_VGB = Impl_VGB + eps*qx            ! perturbation
  !
  ! ImplEps_VGB'=ImplEps_VGB + R(ImplEps_VGB,dtexpl)  ! advance ImplEps_VGB
  !
  ! dR/dw.qx = (R(w+eps*qx)-R(w))/eps 
  !          = [(ImplEps_VGB'-ImplEps_VGB) - (Impl_VGB'-Impl_VGB)]/eps/dtexpl
  !          = (ImplEps_VGB'-Impl_VGB')/eps/dtexpl - qx/dtexpl
  !
  ! L.qx = dx - beta*dt*dR/dw.qx 
  !      = (1 + beta*dtcoeff)*qx - beta*dtcoeff*(ImplEps_VGB' - w')/eps
  !
  ! where w=Impl_VGB, w'=w+R_low, beta=ImplCoeff, eps=sqrt(JacobianEps)/||qx||
  ! instead of eps=(JacobianEps)^(1/2)*(Impl_VGB.qx)/(qx.qx) suggested by Keyes

  use ModProcMH
  use ModMain, ONLY : Itest,Jtest,Ktest,VARtest
  use ModImplicit
  use ModMpi
  implicit none

  integer, intent(in):: nn
  real, intent(in)   :: qx(nn)
  ! Sometimes this subroutine called with the same array in both arguments
  ! that's why the intent of qy cannot be set to out.
  real, intent(inout):: qy(nn)

  real, allocatable, save:: ImplEps_VCB(:,:,:,:,:)
  integer:: n,i,j,k,iw,implBLK, iError
  real:: qeps, qxnrm, qxnrm_total, q1, q2

  logical :: oktest, oktest_me
  !----------------------------------------------------------------------------
  call set_oktest('impl_matvec_free', oktest, oktest_me)

  call timing_start('matvec_free')

  if(UseSemiImplicit)then
     call get_semi_impl_matvec(qx, qy, nn)
     call timing_stop('matvec_free')
     RETURN
  end if

  if(.not.allocated(ImplEps_VCB))allocate(ImplEps_VCB(nw,nI,nJ,nK,MaxImplBLK))

  qxnrm=sum(qx(1:nimpl)**2)
  call MPI_allreduce(qxnrm, qxnrm_total, 1, MPI_REAL, MPI_SUM,iComm,iError)

  if(oktest_me)write(*,*)'impl_matvec_free initial n,sum(x**2)=',nn,qxnrm_total

  qxnrm=sqrt(qxnrm_total/nimpl_total)

  if(qxnrm<smalldouble)qxnrm=1.0

  qeps=sqrt(JacobianEps)/qxnrm

  if(oktest_me)write(*,*)'qeps, qxnrm =',qeps,qxnrm

  n=0
  do implBLK=1,nImplBLK; do k=1,nK; do j=1,nJ; do i=1,nI; do iw=1,nw; 
     n=n+1
     ImplEps_VCB(iw,i,j,k,implBLK) = Impl_VGB(iw,i,j,k,implBLK) &
          + qeps*qx(n)*wnrm(iw)
     !DEBUG no perturbation
     !ImplEps_VCB(iw,i,j,k,implBLK)=Impl_VGB(iw,i,j,k,implBLK)
  enddo; enddo; enddo; enddo; enddo

  if(oktest)then
     call MPI_allreduce(sum(ImplEps_VCB(:,:,:,:,1:nImplBLK)**2),q1,1,&
          MPI_REAL,MPI_SUM,iComm,iError)
     if(oktest_me)write(*,*)'sum(ImplEps_VCB**2)=',q1
     if(oktest_me.and.nImplBLK>0)write(*,*)'ImplEps_VCB(test)=',&
          ImplEps_VCB(VARtest,Itest,Jtest,Ktest,implBLKtest)
  endif

  ! Advance ImplEps_VCB:low order,  no dt, don't subtract
  call get_residual(.true.,.false.,.false.,ImplEps_VCB,ImplEps_VCB) 

  if(oktest)then
     call MPI_allreduce(sum(ImplEps_VCB(:,:,:,:,1:nImplBLK)**2),q1,1,&
          MPI_REAL,MPI_SUM,iComm,iError)
     if(oktest_me)write(*,*)'after advance,sum(ImplEps_VCB**2)=',q1
     if(oktest_me.and.nImplBLK>0)write(*,*)'after advance,ImplEps_VCB(test)=',&
          ImplEps_VCB(VARtest,Itest,Jtest,Ktest,implBLKtest)
  end if

  ! Calculate qy = L.qx = (1 + beta*dtcoeff)*qx 
  !                       - beta*dtcoeff*(ImplEps_VCB' - Impl_VGB')/eps
  ! where ImplEps_VCB  = Impl_VGB + eps*qx, 
  !       ImplEps_VCB' = ImplEps_VCB + dt*R(ImplEps_VCB) and 
  !       Impl_VGB'    = Impl_VGB + dt*R(w)
  ! qy = qx + beta*dtcoeff*qx - beta*dtcoeff*(Impl_VGB + eps*qx 
  !         + R(ImplEps_VCB) - w - R(w))/eps
  !    = qx - beta*dtcoeff*(R(ImplEps_VCB)-R(Impl_VGB))/eps 
  !    = qx - beta*dt*dR/dU*qx

  q1=1.+ImplCoeff*dtcoeff
  q2=ImplCoeff*dtcoeff/qeps

  if(oktest_me)write(*,*)'dtcoeff,ImplCoeff,q1,q2=',dtcoeff,ImplCoeff,q1,q2

  n=0
  do implBLK=1,nImplBLK; do k=1,nK; do j=1,nJ; do i=1,nI; do iw=1,nw
     n=n+1
     qy(n)=q1*qx(n) - q2*(ImplEps_VCB(iw,i,j,k,implBLK) &
          -Impl_VGB(iw,i,j,k,implBLK)-ResImpl_VCB(iw,i,j,k,implBLK))/wnrm(iw)
  enddo; enddo; enddo; enddo; enddo

  call timing_stop('matvec_free')

  if(oktest)then
     call MPI_allreduce(sum(qy(1:n)**2),q1,1,&
          MPI_REAL,MPI_SUM,iComm,iError)
     if(oktest_me.and.nImplBLK>0)&
          write(*,*)'y,x,ImplEps_VCB,Impl_VGB,ResImpl_VCB(test)=',         &
          qy(implVARtest),qx(implVARtest),             &
          ImplEps_VCB(Ktest,VARtest,Itest,Jtest,implBLKtest), &
          Impl_VGB(Ktest,VARtest,Itest,Jtest,implBLKtest),  &
          ResImpl_VCB(VARtest,Itest,Jtest,Ktest,implBLKtest)
     if(oktest_me)write(*,*)'impl_matvec_free final n,sum(qy**2)=',n,q1
  end if

end subroutine impl_matvec_free

!=============================================================================
subroutine impl_preconditioner(Vec_I, PrecVec_I, n)

  use ModImplicit, ONLY: JacobiPrec_I, MAT, nVarSemi, nI, nJ, nwIJK, nIJK, &
       nImplBlk, PrecondType, Stencil1_, Stencil2_, Stencil3_, Stencil4_, &
       Stencil5_, Stencil6_, Stencil7_, PrecondType
  use ModLinearSolver, ONLY: Lhepta, Uhepta, multiply_dilu
  use ModImplHypre, ONLY: hypre_preconditioner

  implicit none

  integer, intent(in) :: n
  real,    intent(in) :: Vec_I(n)
  real,    intent(out):: PrecVec_I(n)

  integer :: iImplBlock
  !-------------------------------------------------------------------------
  PrecVec_I = Vec_I

  if(PrecondType == 'HYPRE')then
     call hypre_preconditioner(n, PrecVec_I)
     RETURN
  end if

  do iImplBlock=1,nImplBLK

     if(PrecondType == 'DILU')then
        call multiply_dilu(nIJK, nVarSemi, nI, nI*nJ,&
             PrecVec_I(nwIJK*(iImplBlock-1)+1),&
             MAT(1,1,1,1,1,Stencil1_,iImplBlock),&
             MAT(1,1,1,1,1,Stencil2_,iImplBlock),&
             MAT(1,1,1,1,1,Stencil3_,iImplBlock),&
             MAT(1,1,1,1,1,Stencil4_,iImplBlock),&
             MAT(1,1,1,1,1,Stencil5_,iImplBlock),&
             MAT(1,1,1,1,1,Stencil6_,iImplBlock),&
             MAT(1,1,1,1,1,Stencil7_,iImplBlock))
     else
        call Lhepta(nIJK, nVarSemi, nI, nI*nJ,&
             PrecVec_I(nwIJK*(iImplBlock-1)+1),&
             MAT(1,1,1,1,1,Stencil1_,iImplBlock),&
             MAT(1,1,1,1,1,Stencil2_,iImplBlock),&
             MAT(1,1,1,1,1,Stencil4_,iImplBlock),&
             MAT(1,1,1,1,1,Stencil6_,iImplBlock))

        call Uhepta(.true., nIJK, nVarSemi, nI, nI*nJ,&
             PrecVec_I(nwIJK*(iImplBlock-1)+1),&
             MAT(1,1,1,1,1,Stencil3_,iImplBlock),&
             MAT(1,1,1,1,1,Stencil5_,iImplBlock),&
             MAT(1,1,1,1,1,Stencil7_,iImplBlock))
     end if
  end do

end subroutine impl_preconditioner
!=============================================================================
subroutine impl_matvec_prec(qx,qy,n)

  ! Calculate qy=P_L.A.P_R.qx for the iterative solver, where 
  ! P_L and P_R are the left and right preconditioner matrices,
  ! L = I - beta*dt*dR/dw, and R is the residual from dw/dt = R(w).
  !
  ! The multiplication by L is done in a matrix free fashion.

  use ModImplicit
  use ModLinearSolver, ONLY: Lhepta, Uhepta, multiply_dilu
  implicit none

  integer, intent(in):: n
  real, intent(in)   :: qx(n)
  real, intent(out)  :: qy(n)

  integer :: implBLK

  logical :: oktest, oktest_me
  !----------------------------------------------------------------------------

  call set_oktest('impl_matvec_prec',oktest,oktest_me)

  if(oktest_me)write(*,*)'impl_matvec_prec initial n,sum(x**2),sum(y**2)=',&
       nimpl,sum(qx(1:nimpl)**2),sum(qy(1:nimpl)**2)

  qy=qx

  ! qy = P_R.qx, where P_R = I, U^{-1}, or U^{-1}L^{-1}
  ! for left, symmetric and right preconditioning, respectively

  if(PrecondSide /= 'left' .and. PrecondType /= 'JACOBI')then
     do implBLK = 1, nImplBLK
        if(PrecondSide=='right') &
             call Lhepta(nIJK, nVarSemi, nI, nI*nJ, &
             qy(nwIJK*(implBLK-1)+1) ,&
             MAT(1,1,1,1,1,Stencil1_,implBLK),&   ! Main diagonal
             MAT(1,1,1,1,1,Stencil2_,implBLK),&   ! -i
             MAT(1,1,1,1,1,Stencil4_,implBLK),&   ! -j
             MAT(1,1,1,1,1,Stencil6_,implBLK))    ! -k
        call Uhepta(.true.,nIJK, nVarSemi, nI, nI*nJ, &
             qy(nwIJK*(implBLK-1)+1) ,  &
             MAT(1,1,1,1,1,Stencil3_,implBLK),  &   ! +i diagonal
             MAT(1,1,1,1,1,Stencil5_,implBLK),  &   ! +j 
             MAT(1,1,1,1,1,Stencil7_,implBLK))      ! +k
     end do
  end if

  call impl_matvec_free(qy,qy,n) ! qy = A.qy

  ! qy = P_L.qy, where P_L==U^{-1}.L^{-1}, L^{-1}, or I
  ! for left, symmetric, and right preconditioning, respectively

  if(PrecondType == 'JACOBI') then
     qy = JacobiPrec_I(1:n)*qy
  elseif(PrecondType == 'DILU') then
     do implBLK = 1, nImplBLK
        call multiply_dilu(nIJK, nVarSemi, nI, nI*nJ, &
             qy(nwIJK*(implBLK-1)+1),&
             MAT(1,1,1,1,1,Stencil1_,implBLK),&
             MAT(1,1,1,1,1,Stencil2_,implBLK),&
             MAT(1,1,1,1,1,Stencil3_,implBLK),&
             MAT(1,1,1,1,1,Stencil4_,implBLK),&
             MAT(1,1,1,1,1,Stencil5_,implBLK),&
             MAT(1,1,1,1,1,Stencil6_,implBLK),&
             MAT(1,1,1,1,1,Stencil7_,implBLK))
     end do
  elseif(PrecondSide /= 'right')then
     do implBLK = 1, nImplBLK
        call Lhepta(nIJK, nVarSemi, nI, nI*nJ,&
             qy(nwIJK*(implBLK-1)+1) ,&
             MAT(1,1,1,1,1,Stencil1_,implBLK),&   ! Main diagonal
             MAT(1,1,1,1,1,Stencil2_,implBLK),&   ! -i
             MAT(1,1,1,1,1,Stencil4_,implBLK),&   ! -j
             MAT(1,1,1,1,1,Stencil6_,implBLK))    ! -k
     end do
     if(PrecondSide == 'left') then
        do implBLK = 1, nImplBLK
           call Uhepta(.true., nIJK, nVarSemi, nI, nI*nJ,&
                qy(nwIJK*(implBLK-1)+1),   &
                MAT(1,1,1,1,1,Stencil3_,implBLK),  &   ! +i diagonal
                MAT(1,1,1,1,1,Stencil5_,implBLK),  &   ! +j
                MAT(1,1,1,1,1,Stencil7_,implBLK))      ! +k
        end do
     end if
  end if

  if(oktest_me)write(*,*)'impl_matvec_prec final n,sum(x**2),sum(y**2)=',&
       n,sum(qx**2),sum(qy**2)

end subroutine impl_matvec_prec

!=============================================================================

subroutine impl_matvec_with(qx,qy,n)

  ! Calculate qy = L.qx, where L is stored in the block hepta diagonal 
  ! matrix MAT

  use ModImplicit
  implicit none

  integer, intent(in) :: n
  real, intent(in)    :: qx(n)
  real, intent(out)   :: qy(n)

  integer :: implBLK
  logical :: oktest, oktest_me
  !---------------------------------------------------------------------------

  call set_oktest('impl_matvec_with',oktest,oktest_me)

  if(oktest_me)write(*,*)'impl_matvec_with initial n,sum(x**2),sum(y**2)=',&
       n,sum(qx**2),sum(qy**2)

  qy = 0.

  do implBLK=1,nImplBLK
     call impl_matvec_with_BLK(MAT(1,1,1,1,1,1,implBLK),&
          qx(1+(implBLK-1)*nwIJK),&
          qy(1+(implBLK-1)*nwIJK))

  end do

  if(oktest_me)write(*,*)'impl_matvec_with final n,sum(x**2),sum(y**2)=',&
       n,sum(qx**2),sum(qy**2)

contains

  subroutine impl_matvec_with_BLK(JAC,qx,qy)

    ! JAC.qx = qy  for a single block

    implicit none

    real, intent(in) :: qx(nVarSemi,nIJK)
    real, intent(inout):: qy(nVarSemi,nIJK)
    real, intent(in) :: JAC(nVarSemi,nVarSemi,nIJK,nstencil)
    integer :: i,j,k

    do j=1,nIJK
       do i=1,nVarSemi
          do k=1,nVarSemi
             qy(i,j)=qy(i,j)+JAC(i,k,j,Stencil1_)*qx(k,j)
          end do
       end do
       if(j>1)then
          do i=1,nVarSemi
             do k=1,nVarSemi
                qy(i,j)=qy(i,j)+JAC(i,k,j,Stencil2_)*qx(k,j-1)
             end do
          end do
       end if
       if(j<nIJK)then
          do i=1,nVarSemi
             do k=1,nVarSemi
                qy(i,j)=qy(i,j)+JAC(i,k,j,Stencil3_)*qx(k,j+1)
             end do
          end do
       end if
       if(j>nI)then
          do i=1,nVarSemi
             do k=1,nVarSemi
                qy(i,j)=qy(i,j)+JAC(i,k,j,Stencil4_)*qx(k,j-nI)
             end do
          end do
       end if
       if(j<=nIJK-nI)then
          do i=1,nVarSemi
             do k=1,nVarSemi
                qy(i,j)=qy(i,j)+JAC(i,k,j,Stencil5_)*qx(k,j+nI)
             end do
          end do
       end if
       if(j>nI*nJ)then
          do i=1,nVarSemi
             do k=1,nVarSemi
                qy(i,j)=qy(i,j)+JAC(i,k,j,Stencil6_)*qx(k,j-nI*nJ)
             end do
          end do
       end if
       if(j<=nIJK-nI*nJ)then
          do i=1,nVarSemi
             do k=1,nVarSemi
                qy(i,j)=qy(i,j)+JAC(i,k,j,Stencil7_)*qx(k,j+nI*nJ)
             end do
          end do
       end if
    end do
  end subroutine impl_matvec_with_BLK

end subroutine impl_matvec_with
