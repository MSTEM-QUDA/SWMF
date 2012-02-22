
module ModPointImplicit

  !DESCRIPTION:
  ! This module implements a point implicit scheme for the implicit
  ! part of the right hand side Rimp = R - Rexp that contributes to the
  ! the implicitly treated variables Uimp, a subset of U=(Uexp, Uimp).
  ! Rimp should depend on the local cell values only: no spatial derivatives!
  !
  ! For a one stage scheme the variables are updated with the following
  ! first order scheme
  !
  ! Uexp^n+1 = Uexp^n + Dt*Rexp(U^n)
  ! Uimp^n+1 = Uimp^n + Dt*Rimp(U^n+1)
  !
  ! For the two stage scheme the following scheme is applied
  !
  ! Uexp^n+1/2 = Uexp^n + Dt/2 * Rexp(U^n)
  ! Uimp^n+1/2 = Uimp^n + Dt/2 * Rimp(U^n+1/2)
  !
  ! Uexp^n+1   = Uexp^n + Dt*Rexp(U^n+1/2)
  ! Uimp^n+1   = Uimp^n + Dt*beta*Rimp(U^n+1) + Dt*(1-beta)*Rimp(U^n)
  !
  ! where beta is in the range 0.5 and 1.0.
  ! The scheme is second order accurate in time for beta = 0.5.
  !
  ! For the general case Rimp is non-linear, and it is linearized as
  !
  ! Rimp(U^n+1/2) = Rimp(Uexp^n+1/2,Uimp^n) + dRimp/dUimp*(Uimp^n+1/2 - Uimp^n)
  ! Rimp(U^n+1)   = Rimp(Uexp^n+1,  Uimp^n) + dRimp/dUimp*(Uimp^n+1   - Uimp^n)
  !
  ! Note that the Jacobian dRimp/dUimp is evaluated at the partially advanced
  ! states (Uexp^n+1/2,Uimp^n) and (Uexp^n+1,Uimp^n) respectively.
  ! If Rimp is linear, the linearization is exact.
  !
  ! Substituting the linearization back into the one-stage and two-stage
  ! schemes yields a linear equation for the differences 
  ! (Uimp^n+1/2 - Uimp^n) and (Uimp^n+1 - Uimp^n), respectively.
  ! Since Rimp depends on the local cell values only, the linear equations
  ! can be solved point-wise for every cell.
  !
  ! The Jacobian can be given analytically by the subroutine passed to
  ! update_point_implicit, or it can be obtained by taking numerical
  ! derivatives of Rimp:
  !
  ! dRimp/dU^w = ((Rimp(Uexp^n+1,Uimp^n+eps^w) - Rimp(Uexp^n+1,Uimp^n))/eps^w
  !                
  ! where eps^w is a small perturbation in the w-th component of Uimp.
  !EOP
  use ModSize, ONLY: nBLK
  use ModMultiFluid, ONLY: UseMultiIon
  implicit none

  save

  private ! except

  logical, public :: UsePointImplicit = UseMultiIon ! Use point impl scheme?
  logical, public :: UsePointImplicit_B(nBLK) = UseMultiIon ! per block
  integer, public, allocatable :: &
       iVarPointImpl_I(:)                        ! Indexes of point impl. vars
  logical, public :: IsPointImplSource=.false.   ! Ask for implicit source
  logical, public :: IsPointImplMatrixSet=.false.! Is dS/dU matrix analytic?
  logical, public :: IsPointImplPerturbed=.false.! Is the state perturbed?

  real, public, allocatable :: &
       DsDu_VVC(:,:,:,:,:), &     ! dS/dU derivative matrix
       EpsPointImpl_V(:)          ! absolute perturbation per variable
  real, public    :: EpsPointImpl ! relative perturbation

  public update_point_implicit    ! do update with point implicit scheme
  public read_point_implicit_param

  ! Local variables
  ! Number of point implicit variables
  integer :: nVarPointImpl = 0    

  ! Coeff. of implicit part: beta=0.5 second order, beta=1.0 first order
  real:: BetaPointImpl = 1.0  

  ! Use asymmetric derivative in numerical Jacobian calculation
  logical:: IsAsymmetric = .true. 

  ! Normalize variables cell-by-cell or per block
  logical:: DoNormalizeCell = .false.

contains
 !============================================================================
  subroutine read_point_implicit_param
    use ModReadParam,     ONLY: read_var
    character(len=*), parameter:: NameSub = 'read_implicit_param'
    !--------------------------------------------------------------------------
    call read_var('UsePointImplicit', UsePointImplicit)
    !the array allows the user to specify the blocks to 
    !use the point implicit scheme individually
    UsePointImplicit_B = UsePointImplicit
    if(UsePointImplicit) then
       call read_var('BetaPointImplicit', BetaPointImpl)
       call read_var('IsAsymmetric',      IsAsymmetric)
       call read_var('DoNormalizeCell',   DoNormalizeCell)
    end if

  end subroutine read_point_implicit_param
  !===========================================================================
  subroutine update_point_implicit(iBlock, &
       calc_point_impl_source, init_point_implicit)

    use ModProcMH,  ONLY: iProc
    use ModKind,    ONLY: nByteReal
    use ModMain,    ONLY: nI, nJ, nK, nIJK, Cfl, nStage, time_accurate, &
         iTest, jTest, kTest, ProcTest, BlkTest, Test_String,VarTest
    use ModAdvance, ONLY: nVar, State_VGB, StateOld_VCB, Source_VC, Time_Blk, &
         DoReplaceDensity
    use ModGeometry,ONLY: True_Blk, True_Cell
    use ModVarIndexes, ONLY: UseMultiSpecies, SpeciesFirst_, SpeciesLast_, &
         Rho_, DefaultState_V
    use ModEnergy, ONLY: calc_energy_cell

    integer, intent(in) :: iBlock
    interface
       subroutine calc_point_impl_source
       end subroutine calc_point_impl_source

       subroutine init_point_implicit
       end subroutine init_point_implicit
    end interface

    integer :: i, j, k, iVar, jVar, iIVar, iJVar
    real :: DtCell, BetaStage, Norm_C(nI,nJ,nK), Epsilon_C(nI,nJ,nK)
    real :: StateExpl_VC(nVar,nI,nJ,nK)
    real :: Source0_VC(nVar,nI,nJ,nK), Source1_VC(nVar,nI,nJ,nK)
    real :: State0_C(nI,nJ,nK)

    real, allocatable, save :: Matrix_II(:,:), Rhs_I(:)

    character(len=*), parameter:: NameSub='update_point_implicit'
    logical :: DoTest, DoTestMe,DoTestCell
    !-------------------------------------------------------------------------

    call timing_start(NameSub)

    if(iProc == ProcTest .and. iBlock == BlkTest)then
       call set_oktest(NameSub,DoTest,DoTestMe)
    else
       DoTest = .false.; DoTestMe = .false.
    end if

    ! Switch to implicit user sources
    IsPointImplSource = .true.

    ! Initialization
    if(.not.allocated(iVarPointImpl_I))then

       ! Set default perturbation parameters
       !
       ! Perturbation_V = abs(State_V)*EpsPointImpl + EpsPointImpl_V

       allocate(EpsPointImpl_V(nVar))
       if(nByteReal == 8)then
          ! Precision of 8-byte arithmetic is roughly P = 1e-12
          if(IsAsymmetric)then
             ! Optimal value is the square root of P for 1-sided derivative
             EpsPointImpl   = 1.e-6
          else 
             ! Optimal value is the 2/3 power of P for 1-sided derivative
             EpsPointImpl   = 1.e-9
          end if
       else
          ! Precision of 8-byte arithmetic is roughly P = 1e-6
          if(IsAsymmetric)then
             ! Optimal value is the square root of P for 1-sided derivative
             EpsPointImpl   = 1.e-3
          else
             ! Optimal value is the 2/3 power of P for 1-sided derivative
             EpsPointImpl   = 1.e-4
          end if
       end if
       ! Set the smallest value for the perturbation. This divides the
       ! difference of the source terms Spert - Sorig, so it cannot be
       ! too small otherwise the error in the source term becomes large.
       EpsPointImpl_V = EpsPointImpl

       ! This call should allocate and set the iVarPointImpl_I index array,
       ! set IsPointImplMatrixSet=.true. if the dS/dU matrix is analytic,
       ! it may also modify the EpsPointImpl and EpsPointImpl_V parameters.

       call init_point_implicit

       if(.not.allocated(iVarPointImpl_I)) call stop_mpi( NameSub // &
            ': init_point_implicit did not set iVarPointImpl_I')

       nVarPointImpl = size(iVarPointImpl_I)

       allocate( &
            DsDu_VVC(nVar, nVar, nI, nJ, nK), &
            Matrix_II(nVarPointImpl, nVarPointImpl), &
            Rhs_I(nVarPointImpl))

       if(iProc==0 .and. index(Test_String, NameSub)>0)then
          write(*,*)NameSub,' allocated arrays: ',DoTest,DoTestMe
          write(*,*)NameSub,': iVarPointImpl_I=',iVarPointImpl_I
          write(*,*)NameSub,': IsPointImplMatrixSet=',IsPointImplMatrixSet
          if(.not.IsPointImplMatrixSet)then
             write(*,*)NameSub,': EpsPointImpl  =',EpsPointImpl
             write(*,*)NameSub,': EpsPointImpl_V=',EpsPointImpl_V
          end if
       end if
    end if

    ! The beta parameter is always one in the first stage
    if(nStage == 1 .or. .not. time_accurate)then
       BetaStage = 1.0
    else
       BetaStage = BetaPointImpl
    end if

    ! Store explicit update
    StateExpl_VC = State_VGB(:,1:nI,1:nJ,1:nK,iBlock)

    ! Put back old values into the implicit variables
    do k=1,nK; do j=1,nJ; do i=1,nI; do iIVar = 1,nVarPointImpl
       iVar = iVarPointImpl_I(iIvar)
       State_VGB(iVar,i,j,k,iBlock) = StateOld_VCB(iVar,i,j,k,iBlock)
    end do; end do; end do; end do

    ! Calculate unperturbed source for right hand side 
    ! and possibly also set analytic Jacobean matrix elements.
    ! Multi-ion may set its elements while the user uses numerical Jacobean.
    Source_VC = 0.0
    DsDu_VVC  = 0.0

    call calc_point_impl_source

    ! Calculate (part of) Jacobean numerically if necessary
    if(.not.IsPointImplMatrixSet)then
       ! Let the source subroutine know that the state is perturbed
       IsPointImplPerturbed = .true.

       ! Save unperturbed source
       Source0_VC = Source_VC(1:nVar,:,:,:)

       ! Perturb all point implicit variables one by one
       do iIVar = 1,nVarPointImpl; iVar = iVarPointImpl_I(iIvar)

          ! Store unperturbed state
          State0_C = State_VGB(iVar,1:nI,1:nJ,1:nK,iBlock)

          ! Get perturbation based on first norm of state in the block
          if(DoNormalizeCell)then
             Norm_C = abs(State0_C)
          elseif(true_BLK(iBlock))then
             Norm_C = sum(abs(State0_C))/nIJK
          else
             Norm_C = sum(abs(State0_C), mask=true_cell(1:nI,1:nJ,1:nK,iBlock)) &
                  /max(count(true_cell(1:nI,1:nJ,1:nK,iBlock)),1)
          end if

          Epsilon_C = EpsPointImpl*Norm_C + EpsPointImpl_V(iVar)

          if(DefaultState_V(iVar) > 0.5 .and. .not. IsAsymmetric)then
             if(DoNormalizeCell)then
                Epsilon_C = min(Epsilon_C, max(1e-30, 0.5*State0_C))
             else
                Epsilon_C = min(Epsilon_C, max(1e-30, 0.5*minval(State0_C)))
             end if
          end if
          ! Perturb the state
          State_VGB(iVar,1:nI,1:nJ,1:nK,iBlock) = State0_C + Epsilon_C

          ! Calculate perturbed source
          Source_VC = 0.0
          call calc_point_impl_source

          if(IsAsymmetric)then

             ! Calculate dS/dU matrix elements
             do iJVar = 1,nVarPointImpl; jVar = iVarPointImpl_I(iJVar)
                DsDu_VVC(jVar,iVar,:,:,:) = DsDu_VVC(jVar,iVar,:,:,:) + &
                     (Source_VC(jVar,:,:,:) - Source0_VC(jVar,:,:,:))/Epsilon_C
             end do

          else
             ! Store perturbed source corresponding to +Epsilon_C perturbation
             Source1_VC = Source_VC(1:nVar,:,:,:)

             ! Perturb the state in opposite direction
             State_VGB(iVar,1:nI,1:nJ,1:nK,iBlock) = State0_C - Epsilon_C

             ! Calculate perturbed source
             Source_VC = 0.0
             call calc_point_impl_source

             ! Calculate dS/dU matrix elements with symmetric differencing
             do iJVar = 1,nVarPointImpl; jVar = iVarPointImpl_I(iJVar)
                DsDu_VVC(jVar,iVar,:,:,:) = DsDu_VVC(jVar,iVar,:,:,:) + &
                     0.5*(Source1_VC(jVar,:,:,:) - Source_VC(jVar,:,:,:)) &
                     /Epsilon_C
             end do

          end if

          !Restore unperturbed state
          State_VGB(iVar,1:nI,1:nJ,1:nK,iBlock) = State0_C

       end do

       ! Restore unperturbed source
       Source_VC(1:nVar,:,:,:) = Source0_VC

    
       IsPointImplPerturbed = .false.
       
    end if

    if(DoTestMe)then
       do iIVar = 1, nVarPointImpl; iVar = iVarPointImpl_I(iIVar)
          write(*,*)NameSub,': DsDu(',iVar,',:)=',&
               (DsDu_VVC(iVar,iVarPointImpl_I(iJVar),iTest,jTest,kTest), &
               iJVar = 1, nVarPointImpl)
       end do
    end if


    ! Do the implicit update
    do k=1,nK; do j=1,nJ; do i=1,nI

       DoTestCell = DoTestMe .and. i==iTest .and. j==jTest .and. k==kTest

       ! Do not update body cells
       if(.not.true_cell(i,j,k,iBlock)) CYCLE

       DtCell = Cfl*time_BLK(i,j,k,iBlock)

       ! The right hand side is Uexpl - Uold + Sold
       do iIVar = 1, nVarPointImpl; iVar = iVarPointImpl_I(iIVar)
          Rhs_I(iIVar) = StateExpl_VC(iVar,i,j,k) &
               - StateOld_VCB(iVar,i,j,k,iBlock) &
               + DtCell * Source_VC(iVar,i,j,k)
       end do

       ! The matrix to be solved for is A = (I - beta*Dt*dS/dU)
       do iIVar = 1, nVarPointImpl; iVar = iVarPointImpl_I(iIVar)
          do iJVar = 1, nVarPointImpl; jVar = iVarPointImpl_I(iJVar)
             Matrix_II(iIVar, iJVar) = - BetaStage*DtCell* &
                  DsDu_VVC( iVar, jVar, i, j, k)
          end do
          ! Add unit matrix
          Matrix_II(iIVar,iIVar) = Matrix_II(iIVar,iIVar) + 1.0

       end do

       ! Solve the A.dU = RHS equation
       call linear_equation_solver(nVarPointImpl, Matrix_II, Rhs_I)

       ! Update: U^n+1 = U^n + dU
       do iIVar = 1, nVarPointImpl; iVar = iVarPointImpl_I(iIVar)
          State_VGB(iVar,i,j,k,iBlock) =&
               StateOld_VCB(iVar,i,j,k,iBlock) + Rhs_I(iIVar)
       end do

       if(UseMultispecies)then
          ! Fix negative species densities
          State_VGB(SpeciesFirst_:SpeciesLast_,i,j,k,iBlock) = &
               max(0.0, State_VGB(SpeciesFirst_:SpeciesLast_,i,j,k,iBlock))

          ! Add up species densities to total density
          if(DoReplaceDensity)State_VGB(Rho_,i,j,k,iBlock) = &
               sum(State_VGB(SpeciesFirst_:SpeciesLast_,i,j,k,iBlock))
       end if

    end do; end do; end do

    ! Make sure that energy is consistent
    call calc_energy_cell(iBlock)

    if(DoTestMe)then
       write(*,*) NameSub, ': StateOld=',&
            StateOld_VCB(:,iTest,jTest,kTest,iBlock)
       write(*,*) NameSub, ': StateExp=',&
            StateExpl_VC(:,iTest,jTest,kTest)
       write(*,*) NameSub, ': StateNew=',&
            State_VGB(:,iTest,jTest,kTest,iBlock)
    end if

    ! Switch back to explicit user sources
    IsPointImplSource = .false.

    call timing_stop(NameSub)

  end subroutine update_point_implicit

  !============================================================================

  subroutine linear_equation_solver(nVar, Matrix_VV, Rhs_V)

    integer, intent(in) :: nVar
    real, intent(inout) :: Matrix_VV(nVar, nVar)
    real, intent(inout) :: Rhs_V(nVar)

    ! This routine solves the system of Nvar linear equations:
    ! 
    !               Matrix_VV*dUCell = Rhs_V.
    ! 
    ! The result is returned in Rhs_V, the matrix is overwritten
    ! with the LU decomposition.
    !
    ! The routine performs a lower-upper (LU) decomposition of the 
    ! square matrix Matrix_VV of rank Nvar and then uses forward and
    ! backward substitution to obtain the solution vector dUCell.
    ! Crout's method with partial implicit pivoting is used to perform
    ! the decompostion.

    integer, parameter :: MAXVAR = 100

    integer :: IL, II, ILMAX, JL, KL, LL, INDX(MAXVAR)
    real    :: SCALING(MAXVAR), LHSMAX, LHSTEMP, TOTALSUM
    real, parameter :: TINY=1.0E-20

    !--------------------------------------------------------------------------
    if(nVar > MAXVAR) call stop_mpi(&
         'ERROR in ModPointImplicit linear solver: MaxVar is too small')

    !\
    ! Loop through each row to get implicit scaling
    ! information.
    !/
    DO IL=1,nVar
       LHSMAX=0.00
       DO JL=1,nVar
          IF (ABS(Matrix_VV(IL,JL)).GT.LHSMAX) LHSMAX=ABS(Matrix_VV(IL,JL))
       END DO
       SCALING(IL)=1.00/LHSMAX
    END DO

    !\
    ! Peform the LU decompostion using Crout's method.
    !/
    DO JL=1,nVar
       DO IL=1,JL-1
          TOTALSUM=Matrix_VV(IL,JL)
          DO KL=1,IL-1
             TOTALSUM=TOTALSUM-Matrix_VV(IL,KL)*Matrix_VV(KL,JL)
          END DO
          Matrix_VV(IL,JL)=TOTALSUM
       END DO
       LHSMAX=0.00
       DO IL=JL,nVar
          TOTALSUM=Matrix_VV(IL,JL)
          DO KL=1,JL-1
             TOTALSUM=TOTALSUM-Matrix_VV(IL,KL)*Matrix_VV(KL,JL)
          END DO
          Matrix_VV(IL,JL)=TOTALSUM
          LHSTEMP=SCALING(IL)*ABS(TOTALSUM)
          IF (LHSTEMP.GE.LHSMAX) THEN
             ILMAX=IL
             LHSMAX=LHSTEMP
          END IF
       END DO
       IF (JL.NE.ILMAX) THEN
          DO KL=1,nVar
             LHSTEMP=Matrix_VV(ILMAX,KL)
             Matrix_VV(ILMAX,KL)=Matrix_VV(JL,KL)
             Matrix_VV(JL,KL)=LHSTEMP
          END DO
          SCALING(ILMAX)=SCALING(JL)
       END IF
       INDX(JL)=ILMAX
       IF (abs(Matrix_VV(JL,JL)).EQ.0.00) Matrix_VV(JL,JL)=TINY
       IF (JL.NE.nVar) THEN
          LHSTEMP=1.00/Matrix_VV(JL,JL)
          DO IL=JL+1,nVar
             Matrix_VV(IL,JL)=Matrix_VV(IL,JL)*LHSTEMP
          END DO
       END IF
    END DO

    !\
    ! Peform the forward and back substitution to obtain
    ! the solution vector.
    !/
    II=0
    DO IL=1,nVar
       LL=INDX(IL)
       TOTALSUM=Rhs_V(LL)
       Rhs_V(LL)=Rhs_V(IL)
       IF (II.NE.0) THEN
          DO JL=II,IL-1
             TOTALSUM=TOTALSUM-Matrix_VV(IL,JL)*Rhs_V(JL)
          END DO
       ELSE IF (TOTALSUM.NE.0.00) THEN
          II=IL
       END IF
       Rhs_V(IL)=TOTALSUM
    END DO
    DO IL=nVar,1,-1
       TOTALSUM=Rhs_V(IL)
       DO JL=IL+1,nVar
          TOTALSUM=TOTALSUM-Matrix_VV(IL,JL)*Rhs_V(JL)
       END DO
       Rhs_V(IL)=TOTALSUM/Matrix_VV(IL,IL)
    END DO

    
  end subroutine linear_equation_solver

end module ModPointImplicit
