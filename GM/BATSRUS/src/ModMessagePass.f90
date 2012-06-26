!^CFG COPYRIGHT UM

module ModMessagePass

  implicit none

  logical:: DoOneCoarserLayer = .true.

contains
  ! moved form file exchange_messages.f90 
  subroutine exchange_messages(DoResChangeOnlyIn, UseOrder2In)

    use ModCellBoundary, ONLY: set_cell_boundary
    use ModProcMH
    use ModMain, ONLY : nBlock, Unused_B, &
         TypeBc_I, time_loop, &
         UseConstrainB,&              !^CFG IF CONSTRAINB 
         UseProjection,&              !^CFG IF PROJECTION
         time_simulation,nOrder,prolong_order,optimize_message_pass
    use ModVarIndexes
    use ModAdvance, ONLY : State_VGB
    use ModGeometry, ONLY : far_field_BCs_BLK        
    use ModPhysics, ONLY : ShockSlope
    use ModFaceValue,ONLY: UseAccurateResChange
    use ModEnergy,   ONLY: calc_energy_ghost, correctP

    use BATL_lib, ONLY: message_pass_cell, DiLevelNei_IIIB
    use ModMpi

    logical, optional, intent(in) :: DoResChangeOnlyIn, UseOrder2In

    integer :: iBlock
    logical :: DoRestrictFace, DoOneLayer, DoTwoCoarseLayers
    logical :: DoFaces
    logical :: UseOrder2=.false.
    integer :: nWidth, nCoarseLayer
    logical :: DoResChangeOnly

    logical:: DoTest, DoTestMe, DoTime, DoTimeMe
    character (len=*), parameter :: NameSub = 'exchange_messages'
    !--------------------------------------------------------------------------
    call set_oktest(NameSub, DoTest, DoTestMe)
    call set_oktest('time_exchange', DoTime, DoTimeMe)

    !!^CFG IF DEBUGGING BEGIN
    ! call testmessage_pass_nodes
    ! call time_message_passing
    !!^CFG END DEBUGGING

    DoResChangeOnly = .false.
    if(present(DoResChangeOnlyIn)) DoResChangeOnly = DoResChangeOnlyIn

    UseOrder2=.false.
    if(present(UseOrder2In)) UseOrder2 = UseOrder2In

    DoRestrictFace = prolong_order==1
    if(UseConstrainB) DoRestrictFace = .false.   !^CFG IF CONSTRAINB

    DoTwoCoarseLayers = &
         nOrder==2 .and. prolong_order==1 .and. .not. DoOneCoarserLayer


    if(DoTestMe)write(*,*) NameSub, &
         ': DoResChangeOnly, UseOrder2, DoRestrictFace, DoTwoCoarseLayers=',&
         DoResChangeOnly, UseOrder2, DoRestrictFace, DoTwoCoarseLayers

    call timing_start('exch_msgs')
    ! Ensure that energy and pressure are consistent and positive in real cells
    !if(prolong_order==2)then     !^CFG IF NOT PROJECTION
    if(.not.DoResChangeOnly) then
       do iBlock = 1, nBlock
          if (Unused_B(iBlock)) CYCLE
          if (far_field_BCs_BLK(iBlock) .and. prolong_order==2)&
               call set_cell_boundary(iBlock,time_simulation,.false.)        
          if(UseConstrainB)call correctP(iBlock)   !^CFG IF CONSTRAINB
          if(UseProjection)call correctP(iBlock)   !^CFG IF PROJECTION
       end do
       !end if                       !^CFG IF NOT PROJECTION
    end if

    if (UseOrder2) then
       call message_pass_cell(nVar, State_VGB,&
            DoResChangeOnlyIn=DoResChangeOnlyIn)
       if(.not.DoResChangeOnly) &
            call fix_boundary_ghost_cells(DoRestrictFace)
    elseif (optimize_message_pass=='all') then
       ! If ShockSlope is not zero then even the first order scheme needs 
       ! two ghost cell layers to fill in the corner cells at the sheared BCs.
       DoOneLayer = nOrder == 1 .and. ShockSlope == 0.0

       nWidth = 2;       if(DoOneLayer)        nWidth = 1
       nCoarseLayer = 1; if(DoTwoCoarseLayers) nCoarseLayer = 2
       call message_pass_cell(nVar, State_VGB, &
            nWidthIn=nWidth, nProlongOrderIn=1, &
            nCoarseLayerIn=nCoarseLayer, DoRestrictFaceIn = DoRestrictFace,&
            DoResChangeOnlyIn=DoResChangeOnlyIn)
       if(.not.DoResChangeOnly) &
            call fix_boundary_ghost_cells(DoRestrictFace)
    else
       ! Do not pass corners if not necessary
       DoFaces = .not.(nOrder == 2 .and. UseAccurateResChange)
       ! Pass one layer if possible
       DoOneLayer = nOrder == 1
       nWidth = 2;       if(DoOneLayer)        nWidth = 1
       nCoarseLayer = 1; if(DoTwoCoarseLayers) nCoarseLayer = 2
       call message_pass_cell(nVar, State_VGB, &
            nWidthIn=nWidth, &
            nProlongOrderIn=1, &
            nCoarseLayerIn=nCoarseLayer,&
            DoSendCornerIn=.not.DoFaces, &
            DoRestrictFaceIn=DoRestrictFace,&
            DoResChangeOnlyIn=DoResChangeOnlyIn)
       if(.not.DoResChangeOnly) &
            call fix_boundary_ghost_cells(DoRestrictFace)
    end if

    do iBlock = 1, nBlock
       if (Unused_B(iBlock)) CYCLE

       ! The corner ghost cells outside the domain are updated
       ! from the ghost cells inside the domain, so the outer 
       ! boundary condition have to be reapplied.
       if(.not.DoResChangeOnly &
            .or. any(abs(DiLevelNei_IIIB(:,:,:,iBlock)) == 1) )then
          if (far_field_BCs_BLK(iBlock)) &
               call set_cell_boundary(iBlock, time_simulation, .false.) 
          if(time_loop.and. any(TypeBc_I=='buffergrid'))&
               call fill_in_from_buffer(iBlock)
       end if

       call calc_energy_ghost(iBlock, DoResChangeOnlyIn=DoResChangeOnlyIn)
    end do

    call timing_stop('exch_msgs')
    if(DoTime)call timing_show('exch_msgs',1)

    if(DoTestMe)write(*,*) NameSub,' finished'

  end subroutine exchange_messages

  !============================================================================
  subroutine fill_in_from_buffer(iBlock)
  
    use ModGeometry,ONLY: R_BLK
    use ModMain,    ONLY: rBuffMin, rBuffMax
    use ModAdvance, ONLY: nVar, State_VGB, Rho_, RhoUx_, RhoUz_, Ux_, Uz_
    use ModProcMH,  ONLY: iProc
    use BATL_lib,   ONLY: MinI, MaxI, MinJ, MaxJ, MinK, MaxK, Xyz_DGB
    implicit none
    integer,intent(in)::iBlock

    integer:: i, j, k
    logical:: DoWrite=.true.
    !------------------------------------------------------------------------

    if(DoWrite)then
       DoWrite=.false.
       if(iProc==0)then
          write(*,*)'Fill in the cells near the inner boundary from the buffer'
       end if
    end if

    do k = MinK, MaxK; do j = MinJ, MaxJ; do i = MinI, MaxI
       if(R_BLK(i,j,k,iBlock) > rBuffMax .or. R_BLK(i,j,k,iBlock) < rBuffMin)&
            CYCLE
       !Get interpolated values from buffer grid:
       call get_from_spher_buffer_grid(&
            Xyz_DGB(:,i,j,k,iBlock), nVar, State_VGB(:,i,j,k,iBlock))

       !Transform primitive variables to conservative ones:
       State_VGB(RhoUx_:RhoUz_,i,j,k,iBlock) = &
            State_VGB(Rho_,i,j,k,iBlock)*State_VGB(Ux_:Uz_,i,j,k,iBlock)

    end do; end do; end do

  end subroutine fill_in_from_buffer

end module ModMessagePass
