!^CFG COPYRIGHT UM
!^CFG FILE IMPLICIT
!==============================================================================
subroutine implicit_init

  ! Set number of implicit blocks and variables, 
  ! and conversion array between explicit and implicit block indices
  ! The implicit blocks are contiguous (all used) from 1 ... nImplBLK

  use ModMain
  use ModImplicit
  use ModAdvance, ONLY: iTypeAdvance_B, ImplBlock_
  implicit none

  logical :: IsInitialized=.false.
  integer :: iBLK, iBlockImpl
  !---------------------------------------------------------------------------

  nImplBLK=count(iTypeAdvance_B(1:nBlock) == ImplBlock_)

  ! Check for too many implicit blocks
  if(nImplBLK>MaxImplBLK)then
     write(*,*)'ERROR: Too many implicit blocks!'
     write(*,*)'MaxImplBLK < nImplBLK :',MaxImplBLK,nImplBLK
     call stop_mpi( &
          'Change number of processors, reduce number of implicit blocks,'// &
          ' or increase MaxImplBLK in ModSize.f90 !')
  end if

  ! Number of implicit variables
  nImpl = nImplBLK*nwIJK
  ! Create conversion array and find the test block
  implBLKtest=1
  iBlockImpl=0
  do iBLK=1,nBlock
     if (iTypeAdvance_B(iBLK) == ImplBlock_) then
        iBlockImpl = iBlockImpl + 1
        impl2iBLK(iBlockImpl)=iBLK
        if(iBLK==BLKtest)implBLKtest=iBlockImpl
     endif
  end do

  ! The index of the test variable in the linear array
  implVARtest=VARtest+nw*(Itest-1+nI*(Jtest-1+nJ*(Ktest-1+nK*(implBLKtest-1))))

  if(.not.IsInitialized)then
     residual = bigdouble
     IsInitialized=.true.
  end if

end subroutine implicit_init
!==============================================================================

subroutine explicit2implicit(imin,imax,jmin,jmax,kmin,kmax,Var_VGB)

  ! Convert data structure Var_VGB of the implicit code to the explicit code

  use ModMain
  use ModAdvance, ONLY : State_VGB, Energy_GBI, nVar
  use ModMultiFluid, ONLY: select_fluid, iFluid, nFluid, iP
  use ModImplicit
  use ModRadDiffusion,   ONLY: get_impl_rad_diff_state
  use ModHeatConduction, ONLY: get_impl_heat_cond_state
  use ModResistivity,    ONLY: get_impl_resistivity_state
  implicit none

  integer,intent(in) :: imin,imax,jmin,jmax,kmin,kmax
  real, intent(out)  :: Var_VGB(nw,imin:imax,jmin:jmax,kmin:kmax,MaxImplBLK)

  integer :: implBLK, iBLK, iVar
  logical :: DoTest, DoTestMe

  character(len=*), parameter:: NameSub = 'explicit2implicit'
  !---------------------------------------------------------------------------
  call set_oktest(NameSub,DoTest,DoTestMe)
  if(DoTestMe)write(*,*)'Starting explicit2implicit: ',&
       'imin,imax,jmin,jmax,kmin,kmax=',imin,imax,jmin,jmax,kmin,kmax

  if(DoTestMe)write(*,*)'E=',Energy_GBI(Itest,Jtest,Ktest,BLKtest,:)

  call timing_start('expl2impl')

  if(UseSemiImplicit)then
     DconsDsemi_VCB(:,:,:,:,1:nImplBLK) = 1.0

     select case(TypeSemiImplicit)
     case('radiation', 'radcond', 'cond')
        call get_impl_rad_diff_state(Var_VGB, DconsDsemi_VCB)
     case('parcond')
        call get_impl_heat_cond_state(Var_VGB, DconsDsemi_VCB)
     case('resistivity')
        call get_impl_resistivity_state(Var_VGB, DconsDsemi_VCB)
     case default
        call stop_mpi(NameSub//': no get_impl_state implemented for' &
             //TypeSemiImplicit)
     end select

     do implBLK=1,nImplBlk
        iBLK=impl2iBLK(implBLK)
        ImplOld_VCB(:,:,:,:,iBLK) = Var_VGB(:,1:nI,1:nJ,1:nK,implBLK)
     end do
  else
     do implBLK=1,nImplBLK
        iBLK = impl2iBLK(implBLK)
        Var_VGB(:,:,:,:,implBLK) = &
             State_VGB(:,imin:imax,jmin:jmax,kmin:kmax,iBLK)

        if(UseImplicitEnergy)then
           do iFluid = 1, nFluid
              call select_fluid
              Var_VGB(iP,:,:,:,implBLK) = &
                   Energy_GBI(imin:imax,jmin:jmax,kmin:kmax,iBLK,iFluid)
           end do
        end if
     end do
  end if

  call timing_stop('expl2impl')

  if(DoTestMe.and.nImplBLK>0)write(*,*)'Finished explicit2implicit: Var_VGB=',&
       Var_VGB(:,iTest,jTest,kTest,implBLKtest)

end subroutine explicit2implicit

!==============================================================================

subroutine impl2expl(Var_VC, iBLK)

  ! Convert the implicit block Var_VC to block iBLK of the explicit code

  use ModSize,     ONLY : nI, nJ, nK
  use ModAdvance,  ONLY : nVar, State_VGB, Energy_GBI
  use ModEnergy,   ONLY : calc_pressure_cell, calc_energy_cell
  use ModMultiFluid, ONLY: iFluid, nFluid, iP_I, iP
  use ModImplicit, ONLY: UseImplicitEnergy
  
  implicit none

  real, intent(in)    :: Var_VC(nVar,nI,nJ,nK)
  integer, intent(in) :: iBLK
  integer :: iVar
  !---------------------------------------------------------------------------

  call timing_start('impl2expl')

  State_VGB(1:nVar,1:nI,1:nJ,1:nK,iBLK) = Var_VC

  if(UseImplicitEnergy)then
     do iFluid = 1, nFluid
        iP = iP_I(iFluid)
        Energy_GBI(1:nI,1:nJ,1:nK,iBLK,iFluid) = Var_VC(iP,:,:,:)
     end do
     call calc_pressure_cell(iBLK)
  else
     call calc_energy_cell(iBLK)
  end if

  call timing_stop('impl2expl')

end subroutine impl2expl

!==============================================================================

subroutine implicit2explicit(Var_VCB)

  use ModMain, ONLY: nI,nJ,nK,MaxImplBLK, iTest, jTest, kTest, BlkTest
  use ModAdvance, ONLY: State_VGB
  use ModImplicit, ONLY: nw, nImplBLK, impl2iBLK, &
       UseSemiImplicit, TypeSemiImplicit
  use ModRadDiffusion,   ONLY: update_impl_rad_diff
  use ModHeatConduction, ONLY: update_impl_heat_cond
  use ModResistivity,    ONLY: update_impl_resistivity
  implicit none

  real :: Var_VCB(nw,nI,nJ,nK,MaxImplBLK)
  integer :: implBLK, iBLK

  logical:: DoTest, DoTestMe
  character(len=*), parameter:: NameSub = 'implicit2explicit'
  !---------------------------------------------------------------------------
  call set_oktest(NameSub,DoTest,DoTestMe)

  do implBLK=1,nImplBLK
     iBLK=impl2iBLK(implBLK)
     if(UseSemiImplicit)then
        select case(TypeSemiImplicit)
        case('radiation', 'radcond', 'cond')
           call update_impl_rad_diff(iBLK, implBLK, Var_VCB(:,:,:,:,implBLK))
        case('parcond')
           call update_impl_heat_cond(iBLK, implBLK, Var_VCB(:,:,:,:,implBLK))
        case('resistivity')
           call update_impl_resistivity(iBLK, implBLK,Var_VCB(:,:,:,:,implBLK))
        case default
           call stop_mpi(NameSub//': no update_impl implemented for' &
                //TypeSemiImplicit)
        end select
     else
        call impl2expl(Var_VCB(:,:,:,:,implBLK),iBLK)
     end if
  end do

  if(DoTestMe)write(*,*) NameSub,': State_VGB=',&
       State_VGB(:,iTest,jTest,kTest,BlkTest)

end subroutine implicit2explicit

!=============================================================================
subroutine get_residual(IsLowOrder, DoCalcTimestep, DoSubtract, Var_VCB, &
     Res_VCB)

  ! If IsLowOrder is true apply low  order scheme
  ! otherwise             apply high order scheme
  !
  ! If DoCalcTimestep is true calculate time step based on CFL condition
  !
  ! If DoSubtract is true return  Res_VCB = Var_VCB(t+dtexpl)-Var_VCB(t) 
  ! otherwise return              Res_VCB = Var_VCB(t+dtexpl)

  use ModMain
  use ModAdvance, ONLY : FluxType,time_BLK
  use ModGeometry, ONLY : true_cell
  use ModImplicit
  use ModMessagePass, ONLY: exchange_messages
  use ModMpi

  implicit none

  logical, intent(in) :: IsLowOrder, DoCalcTimestep, DoSubtract
  real, intent(in)    :: Var_VCB(nVar,nI,nJ,nK,MaxImplBLK)
  ! The actual Var_VCB and Res_VCB arguments may be the same array: 
  ! intent(inout)
  real, intent(inout) :: Res_VCB(nVar,nI,nJ,nK,MaxImplBLK)

  real    :: CflTmp
  integer :: nOrderTmp, nStageTmp, implBLK, iBLK
  character (len=10) :: FluxTypeTmp

  logical :: DoTest, DoTestMe
  !--------------------------------------------------------------------------

  call set_oktest('get_residual',DoTest,DoTestMe)

  call timing_start('get_residual')

  if(DoTestMe.and.nImplBLK>0)&
       write(*,*)'get_residual DoSubtract,IsLowOrder,Var_VCB=',&
       DoSubtract,IsLowOrder,Var_VCB(Ktest,VARtest,Itest,Jtest,implBLKtest)

  nStageTmp       = nStage
  nStage          = 1
  if(IsLowOrder)then
     nOrderTmp    = nOrder
     nOrder       = nOrder_impl
     FluxTypeTmp  = FluxType
     FluxType     = FluxTypeImpl
  endif
  if(UseDtFixed)then
     do implBLK=1,nimplBLK
        iBLK=impl2iBLK(implBLK)
        time_BLK(:,:,:,iBLK)=0.0
        where(true_cell(1:nI,1:nJ,1:nK,iBLK)) &
             time_BLK(1:nI,1:nJ,1:nK,iBLK) = DtExpl
     end do
  else
     CflTmp = Cfl
     Cfl    = 0.5
  end if

  ! Res_VCB = Var_VCB(t+dt)
  call implicit2explicit(Var_VCB)
  call exchange_messages
  call advance_expl(DoCalcTimestep, -1)
  call explicit2implicit(1,nI,1,nJ,1,nK,Res_VCB)

  if(DoSubtract) Res_VCB(:,:,:,:,1:nImplBLK) = Res_VCB(:,:,:,:,1:nImplBLK) &
       - Var_VCB(:,:,:,:,1:nImplBLK)

  if(DoTestMe.and.nImplBLK>0)write(*,*)'get_residual Res_VCB:',&
       Res_VCB(VARtest,Itest,Jtest,Ktest,implBLKtest)

  ! Restore global variables
  nStage      = nStageTmp
  if(IsLowOrder)then
     nOrder   = nOrderTmp
     FluxType = FluxTypeTmp 
  end if
  if (.not.UseDtFixed) Cfl = CflTmp

  call timing_stop('get_residual')

end subroutine get_residual
!==============================================================================
subroutine set_semi_impl_range

  use ModRadDiffusion, ONLY: set_rad_diff_range

  implicit none
  
  !select case(TypeSemiImplicit)
  call set_rad_diff_range

end subroutine set_semi_impl_range
!==============================================================================
subroutine get_semi_impl_rhs(StateImpl_VGB, Rhs_VCB)

  use ModProcMH, ONLY: iProc
  use ModImplicit, ONLY: StateSemi_VGB, nw, nVarSemi, nImplBlk, impl2iblk, &
       TypeSemiImplicit, iVarSemiMin, iVarSemiMax, nVarSemi, &
       FluxImpl_VXB, FluxImpl_VYB, FluxImpl_VZB, UseAccurateRadiation
  use ModLinearSolver, ONLY: UsePDotADotP
  use ModMain, ONLY: dt
  use ModSize, ONLY: nI, nJ, nK, MaxImplBlk
  use ModRadDiffusion,   ONLY: get_rad_diffusion_rhs
  use ModHeatConduction, ONLY: get_heat_conduction_rhs
  use ModResistivity,    ONLY: get_resistivity_rhs
  use ModMessagePass, ONLY: message_pass_dir
  use ModGeometry, ONLY: vInv_CB
  use BATL_lib, ONLY: message_pass_cell, message_pass_face, &
       apply_flux_correction_block

  implicit none

  real, intent(in)  :: StateImpl_VGB(nw,0:nI+1,0:nJ+1,0:nK+1,MaxImplBlk)
  real, intent(out) :: Rhs_VCB(nVarSemi,nI,nJ,nK,MaxImplBlk)

  integer :: iImplBlock, iBlock, i, j, k, iVar

  character(len=*), parameter:: NameSub = 'get_semi_impl_rhs'
  !------------------------------------------------------------------------
  ! Fill in StateSemi so it can be message passed
  do iImplBlock = 1, nImplBLK
     iBlock = impl2iBLK(iImplBlock)
     do k = 1, nK; do j = 1, nJ; do i = 1, nI
        StateSemi_VGB(:,i,j,k,iBlock) = &
             StateImpl_VGB(iVarSemiMin:iVarSemiMax,i,j,k,iImplBlock)
     end do; end do; end do
  end do

  ! Message pass to fill in ghost cells 
  select case(TypeSemiImplicit)
  case('radiation', 'radcond', 'cond')
     if(UseAccurateRadiation)then
        call message_pass_cell(nVarSemi, StateSemi_VGB, nWidthIn=2, &
             nProlongOrderIn=1, nCoarseLayerIn=2, DoRestrictFaceIn = .true.)
     else
        call message_pass_dir(iDirMin=1, iDirMax=3, Width=1, &
             SendCorners=.false., ProlongOrder=1, nVar=nVarSemi, &
             Sol_VGB=StateSemi_VGB, restrictface=.true.)
     end if
  case('parcond','resistivity')
     call message_pass_cell(nVarSemi, StateSemi_VGB, nWidthIn=2, &
          nProlongOrderIn=1, nCoarseLayerIn=2, DoRestrictFaceIn = .true.)
  case default
     call stop_mpi(NameSub//': no get_rhs message_pass implemented for' &
          //TypeSemiImplicit)
  end select

  do iImplBlock = 1, nImplBLK
     iBlock = impl2iBLK(iImplBlock)

     call get_semi_implicit_bc(iBlock, iImplBlock, .false.)

     select case(TypeSemiImplicit)
     case('radiation', 'radcond', 'cond')
        UsePDotADotP = .false.
        call get_rad_diffusion_rhs(iBlock, StateSemi_VGB(:,:,:,:,iBlock), &
             Rhs_VCB(:,:,:,:,iImplBlock), IsLinear=.false.)
     case('parcond')
        call get_heat_conduction_rhs(iBlock, StateSemi_VGB(:,:,:,:,iBlock), &
             Rhs_VCB(:,:,:,:,iImplBlock), IsLinear=.false.)
     case('resistivity')
        call get_resistivity_rhs(iBlock, StateSemi_VGB(:,:,:,:,iBlock), &
             Rhs_VCB(:,:,:,:,iImplBlock), IsLinear=.false.)
     case default
        call stop_mpi(NameSub//': no get_rhs implemented for' &
             //TypeSemiImplicit)
     end select
  end do

  if(TypeSemiImplicit == 'parcond' .or. TypeSemiImplicit == 'resistivity' &
       .or. UseAccurateRadiation)then
     call message_pass_face(nVarSemi, FluxImpl_VXB, FluxImpl_VYB, FluxImpl_VZB)

     do iImplBlock = 1, nImplBLK
        iBlock = impl2iBLK(iImplBlock)

        ! zero ghost cells for Rhs_VCB
        call apply_flux_correction_block(iBlock, nVarSemi, 0, &
             Rhs_VCB(:,:,:,:,iImplBlock), &
             FluxImpl_VXB, FluxImpl_VYB, FluxImpl_VZB)
     end do
  end if

  do iImplBlock = 1, nImplBLK
     iBlock = impl2iBLK(iImplBlock)

     do k = 1, nK; do j = 1, nJ; do i = 1, nI
        Rhs_VCB(:,i,j,k,iImplBlock) = Rhs_VCB(:,i,j,k,iImplBlock) &
             / vInv_CB(i,j,k,iBlock)
     end do; end do; end do
  end do

end subroutine get_semi_impl_rhs
!==============================================================================
subroutine get_semi_impl_matvec(x_I, y_I, MaxN)

  ! Calculate y_I = A.x_I where A is the linearized sem-implicit operator

  use ModImplicit, ONLY: StateSemi_VGB, ResImpl_VCB, &
       FluxImpl_VXB, FluxImpl_VYB, FluxImpl_VZB, &
       nImplBlk, impl2iblk, &
       TypeSemiImplicit, UseSplitSemiImplicit, &
       iVarSemiMin, iVarSemiMax, iVarSemi, nVarSemi, &
       ImplCoeff, DconsDsemi_VCB, KrylovType, UseAccurateRadiation
  use ModMain, ONLY: dt
  use ModSize, ONLY: nI, nJ, nK, MaxImplBlk
  use ModRadDiffusion,   ONLY: get_rad_diffusion_rhs
  use ModHeatConduction, ONLY: get_heat_conduction_rhs
  use ModResistivity,    ONLY: get_resistivity_rhs
  use ModMessagePass, ONLY: message_pass_dir
  use ModGeometry, ONLY: vInv_CB
  use ModLinearSolver, ONLY: UsePDotADotP, pDotADotPPe
  use BATL_lib, ONLY: message_pass_cell, message_pass_face, &
       apply_flux_correction_block
  implicit none

  integer, intent(in):: MaxN
  real, intent(in)   :: x_I(MaxN)
  ! Sometimes this subroutine is called with the same array in both arguments
  ! that's why the intent of y_I cannot be set to out.
  real, intent(inout):: y_I(MaxN)

  integer :: iImplBlock, iBlock, i, j, k, iVar, n
  real :: Volume

  character(len=*), parameter:: NameSub = 'get_semi_impl_matvec'
  !------------------------------------------------------------------------

  ! Fill in StateSemi so it can be message passed
  n = 0
  do iImplBlock = 1, nImplBLK
     iBlock = impl2iBLK(iImplBlock)
     do k = 1, nK; do j = 1, nJ; do i = 1, nI; do iVar = 1, nVarSemi
        n = n + 1
        StateSemi_VGB(iVar,i,j,k,iBlock) = x_I(n) !!! *wnrm(iVar)
     end do; end do; end do; end do
  end do

  ! Message pass to fill in ghost cells 
  select case(TypeSemiImplicit)
  case('radiation', 'radcond', 'cond')

     if(UseAccurateRadiation)then
        UsePDotADotP = .false.

        call message_pass_cell(nVarSemi, StateSemi_VGB, nWidthIn=2, &
             nProlongOrderIn=1, nCoarseLayerIn=2, DoRestrictFaceIn = .true.)
     else
        !\
        ! Initialize the computation of (p \cdot A \cdot P) form
        UsePDotADotP = KrylovType == 'CG'

        pDotADotPPe = 0.0

        call message_pass_dir(iDirMin=1, iDirMax=3, Width=1, &
             SendCorners=.false., ProlongOrder=1, nVar=nVarSemi, &
             Sol_VGB=StateSemi_VGB, restrictface=.true.)
     end if
  case('parcond','resistivity')
     call message_pass_cell(nVarSemi, StateSemi_VGB, nWidthIn=2, &
          nProlongOrderIn=1, nCoarseLayerIn=2, DoRestrictFaceIn = .true.)
  case default
     call stop_mpi(NameSub//': no get_rhs message_pass implemented for' &
          //TypeSemiImplicit)
  end select

  n = 0
  do iImplBlock = 1, nImplBLK
     iBlock = impl2iBLK(iImplBlock)

     call get_semi_implicit_bc(iBlock, iImplBlock, .true.)

     select case(TypeSemiImplicit)
     case('radiation', 'radcond', 'cond')
        call get_rad_diffusion_rhs(iBlock, StateSemi_VGB(:,:,:,:,iBlock), &
             ResImpl_VCB(:,:,:,:,iImplBlock), IsLinear = .true.)
     case('parcond')
        call get_heat_conduction_rhs(iBlock, StateSemi_VGB(:,:,:,:,iBlock), &
             ResImpl_VCB(:,:,:,:,iImplBlock), IsLinear = .true.)
     case('resistivity')
        call get_resistivity_rhs(iBlock, StateSemi_VGB(:,:,:,:,iBlock), &
             ResImpl_VCB(:,:,:,:,iImplBlock), IsLinear = .true.)
     case default
        call stop_mpi(NameSub//': no get_rhs implemented for' &
             //TypeSemiImplicit)
     end select

     if(UsePDotADotP)then
        if(UseSplitSemiImplicit)then
           do k=1,nK; do j=1,nJ; do i=1,nI
              Volume = 1.0/vInv_CB(i,j,k,iBlock)
              n = n + 1
              pDotADotPPe = pDotADotPPe +  &
                   Volume*x_I(n)**2*DconsDsemi_VCB(iVarSemi,i,j,k,iImplBlock)&
                   /(dt * ImplCoeff)
           end do; enddo; enddo
        else
           do k=1,nK; do j=1,nJ; do i=1,nI
              Volume = 1.0/vInv_CB(i,j,k,iBlock)
              do iVar = 1, nVarSemi
                 n = n + 1
                 pDotADotPPe = pDotADotPPe +  &
                      Volume*x_I(n)**2*DconsDsemi_VCB(iVar,i,j,k,iImplBlock) &
                      /(dt * ImplCoeff)
              enddo
           enddo; enddo; enddo
        end if
     end if

  end do

  if(TypeSemiImplicit == 'parcond' .or. TypeSemiImplicit == 'resistivity' &
       .or. UseAccurateRadiation)then
     call message_pass_face(nVarSemi, FluxImpl_VXB, FluxImpl_VYB, FluxImpl_VZB)

     do iImplBlock = 1, nImplBLK
        iBlock = impl2iBLK(iImplBlock)

        ! zero ghost cells for ResImpl_VCB
        call apply_flux_correction_block(iBlock, nVarSemi, 0, &
             ResImpl_VCB(:,:,:,:,iImplBlock), &
             FluxImpl_VXB, FluxImpl_VYB, FluxImpl_VZB)
     end do
  end if

  n=0
  do iImplBlock = 1, nImplBLK
     iBlock = impl2iBLK(iImplBlock)

     if(UseSplitSemiImplicit)then
        do k=1,nK; do j=1,nJ; do i=1,nI
           Volume = 1.0/vInv_CB(i,j,k,iBlock)
           n = n + 1
           y_I(n) = &
                Volume*(x_I(n)*DconsDsemi_VCB(iVarSemi,i,j,k,iImplBlock)/dt &
                - ImplCoeff * ResImpl_VCB(1,i,j,k,iImplBlock))
         end do; enddo; enddo
     else
        do k=1,nK; do j=1,nJ; do i=1,nI
           Volume = 1.0/vInv_CB(i,j,k,iBlock)
           do iVar = 1, nVarSemi
              n = n + 1
              y_I(n) = Volume*(x_I(n)*DconsDsemi_VCB(iVar,i,j,k,iImplBlock)/dt&
                   - ImplCoeff * ResImpl_VCB(iVar,i,j,k,iImplBlock))
            enddo
        enddo; enddo; enddo
     end if
  end do
  if (UsePDotADotP)then
     pDotADotPPe = pDotADotPPe * ImplCoeff
  else
     pDotADotPPe = 0.0
  end if

end subroutine get_semi_impl_matvec
!==============================================================================
subroutine get_semi_impl_jacobian

  use ModImplicit, ONLY: nw, nImplBlk, impl2iblk, TypeSemiImplicit, &
       PrecondType, DnInitHypreAmg, &
       UseSplitSemiImplicit, iVarSemi, &
       nStencil, MAT, ImplCoeff, DconsDsemi_VCB !!!, wnrm
  use ModRadDiffusion,   ONLY: add_jacobian_rad_diff
  use ModHeatConduction, ONLY: add_jacobian_heat_cond
  use ModResistivity,    ONLY: add_jacobian_resistivity
  use ModMain, ONLY: nI, nJ, nK, Dt, n_step
  use ModGeometry, ONLY: vInv_CB
  use ModImplHypre, ONLY: hypre_set_matrix_block, hypre_set_matrix, &
       DoInitHypreAmg

  implicit none

  integer :: iImplBlock, iBlock, i, j, k, iStencil, iVar, jVar
  real    :: Coeff

  integer:: nStepLast = -1

  character(len=*), parameter:: NameSub = 'get_semi_impl_jacobian'
  !---------------------------------------------------------------------------
  do iImplBlock = 1, nImplBLK
     iBlock = impl2iBLK(iImplBlock)

     ! All elements have to be set
     MAT(:,:,:,:,:,:,iImplBlock) = 0.0

     ! Get dR/dU
     select case(TypeSemiImplicit)
     case('radiation', 'radcond', 'cond')
        call add_jacobian_rad_diff(iBlock, MAT(:,:,:,:,:,:,iImplBlock))
     case('parcond')
        call add_jacobian_heat_cond(iBlock, MAT(:,:,:,:,:,:,iImplBlock))
     case('resistivity')
        call add_jacobian_resistivity(iBlock, MAT(:,:,:,:,:,:,iImplBlock))
     case default
        call stop_mpi(NameSub//': no add_jacobian implemented for' &
             //TypeSemiImplicit)
     end select

     ! Form A = Volume*(1/dt - ImplCoeff*dR/dU) (symmetrized for sake of CG)
     do iStencil = 1, nStencil; do k = 1, nK; do j = 1, nJ; do i = 1, nI
        Coeff = - ImplCoeff / vInv_CB(i,j,k,iBlock)
        MAT(:, :, i, j, k, iStencil, iImplBlock) = &
             Coeff * MAT(:, :, i, j, k, iStencil, iImplBlock)
     end do; end do; end do; end do
     do k = 1, nK; do j = 1, nJ; do i = 1, nI
        Coeff = 1.0/(dt*vInv_CB(i,j,k,iBlock))
        if(UseSplitSemiImplicit)then
           MAT(1,1,i,j,k,1,iImplBlock) = &
                Coeff*DconsDsemi_VCB(iVarSemi,i,j,k,iImplBlock) &
                + MAT(1,1,i,j,k,1,iImplBlock)
        else
           do iVar = 1, nw
              MAT(iVar,iVar,i,j,k,1,iImplBlock) = &             
                   Coeff*DconsDsemi_VCB(iVar,i,j,k,iImplBlock) &
                   + MAT(iVar,iVar,i,j,k,1,iImplBlock) 
           end do
        end if
     end do; end do; end do

     if(PrecondType == 'HYPRE') &
          call hypre_set_matrix_block(iImplBlock, MAT(:,:,:,:,:,:,iImplBlock))

  end do

  if(PrecondType == 'HYPRE')then
     if(nStepLast < 0 .or. n_step - nStepLast >= DnInitHypreAmg)then
        DoInitHypreAmg = .true.
        nStepLast = n_step
     end if
     call hypre_set_matrix
  end if

end subroutine get_semi_impl_jacobian

!==============================================================================

subroutine get_semi_implicit_bc(iBlock, iImplBlock, IsLinear)

  use ModRadDiffusion, ONLY: set_rad_outflow_bc
  use ModImplicit, ONLY: UseSplitSemiImplicit, iVarSemiMin, iVarSemiMax, &
       StateSemi_VGB, iTrImplFirst, iTrImplLast, iEradImpl
  use ModMain,     ONLY: TypeBc_I
  use ModParallel, ONLY: NOBLK, NeiLev
  use ModUser,     ONLY: user_set_outerbcs
  use BATL_size,   ONLY: nI, nJ, nK, nDim

  implicit none

  integer, intent(in) :: iBlock, iImplBlock
  logical, intent(in) :: IsLinear

  logical :: IsFound
  integer :: i, j, k, iVar
  character(len=20), parameter :: TypeUserBc = 'usersemi'
  character(len=20), parameter :: TypeUserBcLinear = 'usersemilinear'
  character(len=*),  parameter :: NameSub = 'get_semi_implicit_bc'
  !----------------------------------------------------------------------------

  if(NeiLev(1,iBlock) == NOBLK)then
     if(TypeBc_I(1) == 'outflow' .or. TypeBc_I(1) == 'float')then
        do iVar = iVarSemiMin, iVarSemiMax
           if(iVar < iTrImplFirst .or. iVar > iTrImplLast)then
              ! For non-radiation variables
              if(IsLinear)then
                 StateSemi_VGB(iVar,0,:,:,iBlock) = 0.0
              else
                 StateSemi_VGB(iVar,0,:,:,iBlock) = &
                      StateSemi_VGB(iVar,1,:,:,iBlock)
              end if
           elseif(iVar == iTrImplFirst .or. UseSplitSemiImplicit)then
              ! For radiation variables (only call once when unsplit)
              call set_rad_outflow_bc(1,iBlock, iImplBlock, &
                   StateSemi_VGB(:,:,:,:,iBlock), IsLinear)
           end if
        end do
     elseif(TypeBc_I(1) == 'user')then
        if(IsLinear)then
           StateSemi_VGB(:,0,:,:,iBlock) = 0.0
           call user_set_outerbcs(iBlock, 1, TypeUserBcLinear, IsFound)
        else
           IsFound = .false.
           call user_set_outerbcs(iBlock, 1, TypeUserBc, IsFound)
           if(.not. IsFound) call stop_mpi(NameSub//': unknown TypeBc=' &
                //TypeUserBc//' on iSide=1 in user_set_outerbcs')
        end if
     elseif(TypeBc_I(1) == 'reflect')then
        StateSemi_VGB(:,0,:,:,iBlock) = StateSemi_VGB(:,1,:,:,iBlock)
     else
        call stop_mpi(NameSub//': unknown TypeBc_I(1)='//TypeBc_I(1))
     end if
  end if
  if(NeiLev(2,iBlock) == NOBLK)then
     if(TypeBc_I(2) == 'outflow' .or. TypeBc_I(2) == 'float')then
        do iVar = iVarSemiMin, iVarSemiMax
           if(iVar < iTrImplFirst .or. iVar > iTrImplLast)then
              if(IsLinear)then
                 StateSemi_VGB(iVar,nI+1,:,:,iBlock) = 0.0
              else
                 StateSemi_VGB(iVar,nI+1,:,:,iBlock) = &
                      StateSemi_VGB(iVar,nI,:,:,iBlock)
              end if
           elseif(iVar == iTrImplFirst .or. UseSplitSemiImplicit)then
              call set_rad_outflow_bc(2, iBlock, iImplBlock, &
                   StateSemi_VGB(:,:,:,:,iBlock), IsLinear)
           end if
        end do
     elseif(TypeBc_I(2) == 'user')then
        if(IsLinear)then
           StateSemi_VGB(:,nI+1,:,:,iBlock) = 0.0
           call user_set_outerbcs(iBlock, 2, TypeUserBcLinear, IsFound)
        else
           IsFound = .false.
           call user_set_outerbcs(iBlock, 2, TypeUserBc, IsFound)
           if(.not. IsFound) call stop_mpi(NameSub//': unknown TypeBc=' &
                //TypeUserBc//' on iSide=2 in user_set_outerbcs')
        end if
     elseif(TypeBc_I(2) == 'reflect')then
        StateSemi_VGB(:,nI+1,:,:,iBlock) = StateSemi_VGB(:,nI,:,:,iBlock)
     else
        call stop_mpi(NameSub//': unknown TypeBc_I(2)='//TypeBc_I(2))
     end if
  end if
  if(nDim > 1 .and. NeiLev(3,iBlock) == NOBLK)then
     if(TypeBc_I(3) == 'outflow' .or. TypeBc_I(3) == 'float')then
        do iVar = iVarSemiMin, iVarSemiMax
           if(iVar < iTrImplFirst .or. iVar > iTrImplLast)then
              if(IsLinear)then
                 StateSemi_VGB(iVar,:,0,:,iBlock) = 0.0
              else
                 StateSemi_VGB(iVar,:,0,:,iBlock) = &
                      StateSemi_VGB(iVar,:,1,:,iBlock)
              end if
           elseif(iVar == iTrImplFirst .or. UseSplitSemiImplicit)then
              call set_rad_outflow_bc(3, iBlock, iImplBlock, &
                   StateSemi_VGB(:,:,:,:,iBlock), IsLinear)
           end if
        end do
     elseif(TypeBc_I(3) == 'user')then
        if(IsLinear)then
           StateSemi_VGB(:,:,0,:,iBlock) =  0.0
           call user_set_outerbcs(iBlock, 3, TypeUserBcLinear, IsFound)
        else
           IsFound = .false.
           call user_set_outerbcs(iBlock, 3, TypeUserBc, IsFound)
           if(.not. IsFound) call stop_mpi(NameSub//': unknown TypeBc=' &
                //TypeUserBc//' on iSide=3 in user_set_outerbcs')
        end if
     elseif(TypeBc_I(3) == 'reflect')then
        StateSemi_VGB(:,:,0,:,iBlock) = StateSemi_VGB(:,:,1,:,iBlock)
     elseif(TypeBc_I(3) == 'shear')then
        call semi_bc_shear(3)
     else
        call stop_mpi(NameSub//': unknown TypeBc_I(3)='//TypeBc_I(3))
     end if
  end if
  if(nDim > 1 .and. NeiLev(4,iBlock) == NOBLK) then
     if(TypeBc_I(4) == 'outflow' .or. TypeBc_I(4) == 'float')then
        do iVar = iVarSemiMin, iVarSemiMax
           if(iVar < iTrImplFirst .or. iVar > iTrImplLast)then
              if(IsLinear)then
                 StateSemi_VGB(iVar,:,nJ+1,:,iBlock) = 0.0
              else
                 StateSemi_VGB(iVar,:,nJ+1,:,iBlock) = &
                      StateSemi_VGB(iVar,:,nJ,:,iBlock)
              end if
           elseif(iVar == iTrImplFirst .or. UseSplitSemiImplicit)then
              call set_rad_outflow_bc(4, iBlock, iImplBlock, &
                   StateSemi_VGB(:,:,:,:,iBlock), IsLinear)
           end if
        end do
     elseif(TypeBc_I(4) == 'user')then
        if(IsLinear)then
           StateSemi_VGB(:,:,nJ+1,:,iBlock) = 0.0
           call user_set_outerbcs(iBlock, 4, TypeUserBcLinear, IsFound)
        else
           IsFound = .false.
           call user_set_outerbcs(iBlock, 4, TypeUserBc, IsFound)
           if(.not. IsFound) call stop_mpi(NameSub//': unknown TypeBc=' &
                //TypeUserBc//' on iSide=4 in user_set_outerbcs')
        end if
     elseif(TypeBc_I(4) == 'reflect')then
        StateSemi_VGB(:,:,nJ+1,:,iBlock) = StateSemi_VGB(:,:,nJ,:,iBlock)
     elseif(TypeBc_I(4) == 'shear')then
        call semi_bc_shear(4)
     else
        call stop_mpi(NameSub//': unknown TypeBc_I(4)='//TypeBc_I(4))
     end if
  end if
  if(nDim > 2 .and. NeiLev(5,iBlock) == NOBLK) then
     if(TypeBc_I(5) == 'outflow' .or. TypeBc_I(5) == 'float')then
        do iVar = iVarSemiMin, iVarSemiMax
           if(iVar < iTrImplFirst .or. iVar > iTrImplLast)then
              if(IsLinear)then
                 StateSemi_VGB(iVar,:,:,0,iBlock) = 0.0
              else
                 StateSemi_VGB(iVar,:,:,0,iBlock) = &
                      StateSemi_VGB(iVar,:,:,1,iBlock)
              end if
           elseif(iVar == iTrImplFirst .or. UseSplitSemiImplicit)then
              call set_rad_outflow_bc(5, iBlock, iImplBlock, &
                   StateSemi_VGB(:,:,:,:,iBlock), IsLinear)
           end if
        end do
     elseif(TypeBc_I(5) == 'user')then
        if(IsLinear)then
           StateSemi_VGB(:,:,:,0,iBlock) = 0.0
           call user_set_outerbcs(iBlock, 5, TypeUserBcLinear, IsFound)
        else
           IsFound = .false.
           call user_set_outerbcs(iBlock, 5, TypeUserBc, IsFound)
           if(.not. IsFound) call stop_mpi(NameSub//': unknown TypeBc=' &
                //TypeUserBc//' on iSide=5 in user_set_outerbcs')
        end if
     elseif(TypeBc_I(5) == 'reflect')then
        StateSemi_VGB(:,:,:,0,iBlock) = StateSemi_VGB(:,:,:,1,iBlock)
     else
        call stop_mpi(NameSub//': unknown TypeBc_I(5)='//TypeBc_I(5))
     end if
  end if
  if(nDim > 2 .and. NeiLev(6,iBlock) == NOBLK)then 
     if(TypeBc_I(6) == 'outflow' .or. TypeBc_I(6) == 'float')then
        do iVar = iVarSemiMin, iVarSemiMax
           if(iVar < iTrImplFirst .or. iVar > iTrImplLast)then
              if(IsLinear)then
                 StateSemi_VGB(iVar,:,:,nK+1,iBlock) = 0.0
              else
                 StateSemi_VGB(iVar,:,:,nK+1,iBlock) = &
                      StateSemi_VGB(iVar,:,:,nK,iBlock)
              end if
           elseif(iVar == iTrImplFirst .or. UseSplitSemiImplicit)then
              call set_rad_outflow_bc(6, iBlock, iImplBlock, &
                   StateSemi_VGB(:,:,:,:,iBlock), IsLinear)
           end if
        end do
     elseif(TypeBc_I(6) == 'user')then
        if(IsLinear)then
           StateSemi_VGB(:,:,:,nK+1,iBlock) = 0.0
           call user_set_outerbcs(iBlock, 6, TypeUserBcLinear, IsFound)
        else
           IsFound = .false.
           call user_set_outerbcs(iBlock, 6, TypeUserBc, IsFound)
           if(.not. IsFound) call stop_mpi(NameSub//': unknown TypeBc=' &
                //TypeUserBc//' on iSide=6 in user_set_outerbcs')
        end if
     elseif(TypeBc_I(6) == 'reflect')then
        StateSemi_VGB(:,:,:,nK+1,iBlock) = StateSemi_VGB(:,:,:,nK,iBlock)
     else
        call stop_mpi(NameSub//': unknown TypeBc_I(6)='//TypeBc_I(6))
     end if
  end if

contains

  subroutine semi_bc_shear(iSide)

    use ModNumConst, ONLY: cTiny
    use ModPhysics, ONLY: ShockSlope
    use ModSize, ONLY: south_, north_

    integer, intent(in) :: iSide

    integer :: Dn, iVar
    !--------------------------------------------------------------------------

    ! If the shock is not tilted, there is nothing to do
    if(abs(ShockSlope)<cTiny) RETURN

    ! Shear according to ShockSlope
    if(ShockSlope < -cTiny)then
       call stop_mpi('ShockSlope must be positive!')
    elseif(ShockSlope > 1.0)then
       call stop_mpi('ShockSlope > 1 not allowed!')
    else
       ! ShockSlope <= 1
       Dn = nint(1.0/ShockSlope)
       if(abs(Dn-1.0/ShockSlope)>cTiny)call stop_mpi( &
            'ShockSlope <= 1 should be the inverse of a round number!')
       select case(iSide)
          ! Shift parallel to X by 1, but copy from distance Dn in Y
       case(south_)
          StateSemi_VGB(:,1:nI,0,:,iBlock) = &
               StateSemi_VGB(:,0:nI-1,Dn,:,iBlock)
       case(north_)
          StateSemi_VGB(:,1:nI,nJ+1,:,iBlock) = &
               StateSemi_VGB(:,2:nI+1,nJ+1-Dn,:,iBlock)
       end select
    end if

  end subroutine semi_bc_shear

end subroutine get_semi_implicit_bc

!==============================================================================

subroutine getsource(iBLK,Var_VCB,SourceImpl_VC)

  ! Get sources for block iBLK using implicit data Var_VCB

  use ModMain
  use ModVarIndexes
  use ModAdvance, ONLY : Source_VC  ! To communicate to calc_sources
  use ModImplicit, ONLY : nw, UseImplicitEnergy

  implicit none

  integer, intent(in) :: iBLK
  real, intent(in)    :: Var_VCB(nI,nJ,nK,nw)
  real, intent(out)   :: SourceImpl_VC(nw,nI,nJ,nK)

  logical :: qUseDivbSource
  integer::iVar, iFluid
  !--------------------------------------------------------------------------

  call timing_start('getsource')

  qUseDivbSource = UseDivbSource
  UseDivbSource  = .false.
  
  call impl2expl(Var_VCB,iBLK)
  globalBLK = iBLK

  !!! Explicit time dependence  t+ImplCoeff*dt !!!
  !call calc_point_sources(t+ImplCoeff*dt)
  call calc_sources

  SourceImpl_VC = Source_VC(1:nVar,:,:,:)
  
  if(UseImplicitEnergy)then
     ! Overwrite pressure source terms with energy source term
     SourceImpl_VC(iP_I,:,:,:) = Source_VC(Energy_:Energy_+nFluid-1,:,:,:)
  end if

  UseDivbSource   =qUseDivbSource
  call timing_stop('getsource')

end subroutine getsource

!==============================================================================
subroutine get_face_flux(StateCons_VC,B0_DC,nI,nJ,nK,iDim,iBlock,Flux_VC)

  ! We need the cell centered physical flux function, but to keep
  ! the implicit scheme general for all equations, we reuse
  ! subroutine get_physical_flux from ModFaceFlux.

  use ModVarIndexes,ONLY: nFluid, nVar, Energy_
  use ModProcMH,   ONLY: iProc
  use ModMain,     ONLY: nDim, x_, y_, z_, &
       ProcTest, BlkTest,iTest,jTest,kTest
  use ModFaceFlux, ONLY: nFlux, iFace, jFace, kFace, Area, &
       set_block_values, set_cell_values, get_physical_flux, &
       HallJx, HallJy, HallJz, UseHallGradPe, DoTestCell
  use ModHallResist, ONLY: UseHallResist, HallJ_CD
  use ModMultiFluid, ONLY: iFluid, nFluid, iP_I, iP
  use ModImplicit,   ONLY: UseImplicitEnergy

  implicit none

  integer, intent(in):: nI,nJ,nK,idim,iBlock
  real, intent(in)   :: StateCons_VC(nVar,nI,nJ,nK)
  real, intent(in)   :: B0_DC(nDim,nI,nJ,nK)
  real, intent(out)  :: Flux_VC(nVar,nI,nJ,nK)

  real :: Primitive_V(nVar), Conservative_V(nFlux), Flux_V(nFlux)

  real :: Un_I(nFluid+1), En, Pe
  integer :: i, j, k

  logical :: DoTest, DoTestMe
  !--------------------------------------------------------------------------

  if(iBlock==BLKtest .and. iProc==PROCtest)then
     call set_oktest('get_face_flux', DoTest, DoTestMe)
  else
     DoTest=.false.; DoTestMe=.false.
  end if

  call set_block_values(iBlock, iDim)
  ! Set iFace=i, jFace=j, kFace=k so that 
  ! call set_cell_values and call get_physical_flux work
  ! This is not quite right but good enough for the preconditioner
  do k = 1, nK; kFace=k; do j = 1, nJ; jFace=j; do i = 1, nI; iFace=i

     DoTestCell = DoTestMe .and. &
          i==iTest .and. j==jTest .and. k==kTest

     Primitive_V = StateCons_VC( :,i, j, k)
     call conservative_to_primitive(Primitive_V)

     !!! Conservative_V(1:nVar) = StateCons_VC( :,i, j, k)
     !!! do iFluid=1, nFluid
     !!!    iP = iP_I(iFluid)
     !!!    Conservative_V(iP) = Primitive_V(iP)
     !!!    Conservative_V(nVar+iFluid) = StateCons_VC( iP,i, j, k)
     !!! end do

     if(UseHallResist)then
        HallJx = HallJ_CD(i, j, k, x_)
        HallJy = HallJ_CD(i, j, k, y_)
        HallJz = HallJ_CD(i, j, k, z_)
     end if

     call set_cell_values

     ! Ignore gradient of electron pressure in the preconditioner
     UseHallGradPe = .false.

     call get_physical_flux(Primitive_V, &
          B0_DC(x_, i, j, k), &
          B0_DC(y_, i, j, k), &
          B0_DC(z_, i, j, k), &
          Conservative_V, Flux_V, Un_I, En, Pe)

     Flux_VC(1:nVar,i,j,k)= Flux_V(1:nVar)*Area

     if(UseImplicitEnergy)then
        ! Replace pressure flux with energy flux
        Flux_VC(iP_I,i,j,k) = Flux_V(Energy_:Energy_+nFluid-1)*Area
     end if

  end do; end do; end do

end subroutine get_face_flux

!==============================================================================
subroutine get_cmax_face(Var_VF,B0_DF,qnI,qnJ,qnK,iDim,iBlock,Cmax)

  use ModProcMH,   ONLY: iProc
  use ModMain,     ONLY: nDim, x_, y_, z_, ProcTest, BlkTest,iTest,jTest,kTest
  use ModImplicit, ONLY: nw
  use ModFaceFlux, ONLY: DoTestCell, iFace, jFace, kFace, Area, &
       set_block_values, set_cell_values, get_speed_max, nFluid, &
       DoLf, DoAw, DoRoe, DoHll, DoHlld, UnLeft_I, UnRight_I
  use ModAdvance,  ONLY: eFluid_

  implicit none

  integer, intent(in):: qnI,qnJ,qnK,idim,iBlock
  real, intent(in)   :: Var_VF(nw,qnI,qnJ,qnK)
  real, intent(in)   :: B0_DF(ndim,qnI,qnJ,qnK)
  real, intent(out)  :: Cmax(qnI,qnJ,qnK)

  real :: Primitive_V(nw), Cmax_I(nFluid)

  character(len=*), parameter:: NameSub = 'get_cmax_face'
  logical :: DoTest, DoTestMe
  !--------------------------------------------------------------------------

  if(iBlock==BLKtest .and. iProc==PROCtest)then
     call set_oktest('get_cmax_face', DoTest, DoTestMe)
  else
     DoTest=.false.; DoTestMe=.false.
  end if

  DoLf  = .true.
  DoAw  = .false.
  DoRoe = .false.
  DoHll = .false.
  DoHlld= .false.

  ! The electron speed is set to zero (I can't remember why)
  UnLeft_I(eFluid_)  = 0.0
  UnRight_I(eFluid_) = 0.0

  call set_block_values(iBlock, iDim)
  do kFace = 1, qnK; do jFace = 1, qnJ; do iFace = 1, qnI

     DoTestCell = DoTestMe .and. &
          iFace==iTest .and. jFace==jTest .and. kFace==kTest

     Primitive_V = Var_VF(:,iFace, jFace, kFace)

     call conservative_to_primitive(Primitive_V)

     call set_cell_values

     call get_speed_max(Primitive_V, &
          B0_DF( x_,iFace, jFace, kFace), &
          B0_DF( y_,iFace, jFace, kFace), &
          B0_DF( z_,iFace, jFace, kFace), &
          cmax_I = Cmax_I)

     cmax(iFace, jFace, kFace) = maxval(Cmax_I)*Area

  end do; end do; end do

  if(DoTestMe)write(*,*) NameSub,': Area, cmax=', &
       Area, cmax(iTest, jTest, kTest)

end subroutine get_cmax_face

!==============================================================================
subroutine conservative_to_primitive(State_V)

  use ModAdvance, ONLY: UseElectronPressure
  use ModImplicit, ONLY: nw, UseImplicitEnergy
  use ModVarIndexes, ONLY: Bx_, Bz_, IsMhd, nFluid, Pe_
  use ModMultiFluid, ONLY: select_fluid, nIonFluid, &
       iFluid, iRho, iRhoUx, iUx, iRhoUz, iUz, iP, &
       iRho_I, iUx_I, iUy_I, iUz_I, iRhoUx_I, iRhoUy_I, iRhoUz_I
  use ModPhysics, ONLY: gm1
  use ModWaves, ONLY: UseWavePressure, WaveFirst_, WaveLast_

  implicit none

  real, intent(inout):: State_V(nw)
  real :: InvRho, InvRho_I(nFluid)
  !---------------------------------------------------------------------------
  if(UseImplicitEnergy)then
     do iFluid = 1, nFluid
        call select_fluid

        InvRho = 1.0/State_V(iRho)

        State_V(iP) = gm1*(State_V(iP) - &
             0.5*sum(State_V(iRhoUx:iRhoUz)**2)*InvRho)

        if(nIonFluid == 1 .and. iFluid == 1)then
           if(UseElectronPressure) State_V(iP) = State_V(iP) - State_V(Pe_)
           if(UseWavePressure) State_V(iP) = State_V(iP) &
                - gm1*sum(State_V(WaveFirst_:WaveLast_))
        end if

        if(iFluid == 1 .and. IsMhd) &
             State_V(iP) = State_V(iP) - 0.5*gm1*sum(State_V(Bx_:Bz_)**2)

        State_V(iUx:iUz) = InvRho*State_V(iRhoUx:iRhoUz)
     end do
  else
     InvRho_I = 1.0/State_V(iRho_I)
     State_V(iUx_I) = InvRho_I*State_V(iRhoUx_I)
     State_V(iUy_I) = InvRho_I*State_V(iRhoUy_I)
     State_V(iUz_I) = InvRho_I*State_V(iRhoUz_I)
  end if

end subroutine conservative_to_primitive

!==============================================================================
subroutine getdt_courant(qdt)

  use ModProcMH
  use ModMain
  use ModAdvance, ONLY : B0_DGB
  use ModGeometry, ONLY : dx_BLK,dy_BLK,dz_BLK,dxyz,true_cell,true_BLK,vInv_CB
  use ModImplicit
  use ModMpi
  implicit none

  real, intent(out) :: qdt

  real :: cmax(nI,nJ,nK), B0_DC(nDim,nI,nJ,nK), qdt_local
  integer :: idim, implBLK, iBLK, iError

  logical :: DoTest, DoTestMe
  !-------------------------------------------------------------------------
  call set_oktest('getdt_courant',DoTest,DoTestMe)

  ! First calculate max(cmax/dx) for each cell and dimension
  qdt_local=0.0
  do implBLK=1,nImplBLK; 
     iBLK=impl2iBLK(implBLK); 
     dxyz(x_)=dx_BLK(iBLK); dxyz(y_)=dy_BLK(iBLK); dxyz(z_)=dz_BLK(iBLK)
     if(UseB0)then
        B0_DC = B0_DGB(:,1:nI,1:nJ,1:nK,iBLK)
     else
        B0_DC = 0.0
     end if

     do idim=1,ndim

        call get_cmax_face(Impl_VGB(1:nw,1:nI,1:nJ,1:nK,implBLK),B0_DC,&
             nI, nJ, nK, iDim, iBlk, Cmax)

        if(.not.true_BLK(iBLK))then
           where(.not.true_cell(1:nI,1:nJ,1:nK,iBLK))cmax=0.0
        end if

        qdt_local=max(qdt_local,maxval(cmax*vInv_CB(:,:,:,iBlk)))

        if(DoTestMe)write(*,*)'getdt_courant idim,dx,cmax,1/qdt=',&
             idim,cmax(Itest,Jtest,Ktest),qdt_local
     end do
  end do

  ! Take global maximum
  call MPI_allreduce(qdt_local,qdt,1,MPI_REAL,MPI_MAX,iComm,iError)

  if(DoTestMe)write(*,*)'1/dt_local,1/dt=',qdt_local,qdt

  ! Take inverse, and reduce so it is OK for 3D calculation
  qdt=0.3/qdt

  if(DoTestMe)write(*,*)'getdt_courant final dt=',qdt

end subroutine getdt_courant
