!  Copyright (C) 2002 Regents of the University of Michigan, 
!  portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
!^CMP FILE SP

module CON_couple_mh_sp

  ! This coupler employs the following global arrays.
  ! SP_Xyz_DI - is the array of the Lagrangian points.
  ! A part of this array, as well as the mask 'SP_IsInIH' is only availbale
  ! at the PE set, at which either IH or SP run. 
  ! This coordinates are expressed in terms of
  ! the length units and with respect to the frame of reference defined in IH.
  ! Another part of this array, as well as the mask 'SP_IsInSC' 
  ! is only available at the PE set, at which either SC or SP run. 
  ! This coordinates are expressed in terms of
  ! the length units and with respect to the frame of reference defined in SC.
  ! SP_XyzSP - in the array of all Lagrangian points, in units and in the 
  ! frame of reference defined at SP, is available only at the PE set, 
  ! at which SP runs.

  use CON_coupler

  use IH_wrapper, ONLY: IH_synchronize_refinement, &        !^CMP IF IH
       IH_extract_line, IH_get_for_sp, IH_get_a_line_point,&!^CMP IF IH
       IH_get_scatter_line, IH_add_to_line, IH_n_particle,& !^CMP IF IH
       IH_LineDD, IH_line_interface_point, &                !^CMP IF IH
       IH_get_particle_indexes, IH_get_particle_coords      !^CMP IF IH

  use SC_wrapper, ONLY: SC_synchronize_refinement, &        !^CMP IF SC
       SC_extract_line, SC_get_for_sp, SC_get_a_line_point,&!^CMP IF SC
       SC_get_scatter_line, SC_n_particle, SC_LineDD, &     !^CMP IF SC
       SC_line_interface_point,&                            !^CMP IF SC
       SC_get_particle_indexes, SC_get_particle_coords      !^CMP IF IH

  use CON_global_message_pass
  use CON_axes

  use SP_wrapper, ONLY: &
       SP_put_from_mh, SP_put_input_time, &
       SP_put_line, SP_n_particle,        &
       SP_get_grid_descriptor_param, &
       SP_get_domain_boundary, SP_put_r_min, &
       SP_interface_point_coords_for_ih, SP_interface_point_coords_for_sc, &
       SP_copy_old_state

  implicit none
  
  private !Except
  public::couple_mh_sp_init
  public::couple_ih_sp              !^CMP IF IH
  public::couple_sc_sp              !^CMP IF SC

  type(GridDescriptorType),save::SP_GridDescriptor !Target
  type(LocalGDType),       save::SP_LocalGD
  type(GridDescriptorType),save::IH_GridDescriptor !Source  !^CMP IF IH
  type(RouterType),save,private::RouterIhSp                 !^CMP IF IH
  type(GridDescriptorType),save::IH_LineGridDesc            !^CMP IF IH
  type(LocalGDType),       save::IH_LocalLineGD             !^CMP IF IH
  type(RouterType),save,private::RouterLineIhSp             !^CMP IF IH

  type(GridDescriptorType),save::SC_GridDescriptor !Source  !^CMP IF SC
  type(RouterType),save,private::RouterScSp                 !^CMP IF SC
  type(GridDescriptorType),save::SC_LineGridDesc            !^CMP IF SC
  type(LocalGDType),save::SC_LocalLineGD                    !^CMP IF SC
  type(RouterType),save,private::RouterLineScSp             !^CMP IF SC

  logical,save::DoInit=.true.

  integer, parameter :: nDim = 3
  integer, parameter :: nAux = 2
  integer :: nLength

  integer::iError
  real,save::rBoundIh=21.0                !^CMP IF IH
  real,save::rBoundSc=1.20                !^CMP IF SC

  ! available directions of interface between SP and MH 
  integer, parameter:: &
       iInterfaceBegin = -1, iInterfaceOrigin = 0, iInterfaceEnd = 1
  
  logical::DoTest,DoTestMe
  character(LEN=*),parameter::NameSub='couple_mh_sp'
  real,dimension(3,3)::ScToIh_DD,ScToSp_DD,IhToSp_DD,SpToSc_DD
  real :: tNow

contains
  !==================================================================
  subroutine couple_mh_sp_init
    use CON_physics, ONLY: get_time
    use ModConst

    logical::DoneRestart

    integer:: iGridMin_D(3), iGridMax_D(3), ierror
    real:: Disp_D(3)
    real, pointer:: CoordMisc_DI(:,:)

    ! available directions of interface between SP and MH 
    ! (see subroutine exchange_lines below)
    integer, parameter:: &
         iInterfaceBegin = -1, iInterfaceOrigin = 0, iInterfaceEnd = 1

    ! solar corona boundary
    real:: RSc, RIh, RMin

    character(len=*), parameter:: NameSub = 'couple_mh_sp_init'
    !----------------------------------------------------------------------
    if(.not.DoInit)return
    call CON_set_do_test(NameSub,DoTest,DoTestMe)
    DoInit=.false.
    !The initialization can be done only once

    call get_time(tSimulationOut=tNow)
    if(is_proc(SP_))call SP_put_input_time(tNow)
    !\
    ! Set grid descriptors for components
    ! Initialize routers
    !/
    call set_standard_grid_descriptor(SP_,GridDescriptor=&
         SP_GridDescriptor)
    if(is_proc(SP_))call set_local_gd(&
         iProc = i_proc(), &
         GridDescriptor = SP_GridDescriptor, &
         LocalGD = SP_LocalGD)


    ! get the value of SC and IH boundary as set in SP
    call SP_get_domain_boundary(RSc, RIh)

    if(use_comp(SC_))then  
       ! Set pair SC-SP
       call set_couple_var_info(SC_, SP_)
       call set_standard_grid_descriptor(SC_,GridDescriptor=&
            SC_GridDescriptor)
       call init_router(SC_GridDescriptor,SP_GridDescriptor,&
            RouterScSp,nMappedPointIndex=nAux)
       call set_standard_grid_descriptor(SC_LineDD,GridDescriptor=&
            SC_LineGridDesc)
       if(is_proc(SC_))call set_local_gd(&
            iProc = i_proc(), &
            GridDescriptor = SC_LineGridDesc, &
            LocalGD = SC_LocalLineGD)
       call init_router(SC_LineGridDesc, SP_GridDescriptor, RouterLineScSp, &
            nMappedPointIndex=0)
       if(RouterScSp%IsProc)then
          call SC_synchronize_refinement(RouterScSp%iProc0Source,&
               RouterScSp%iCommUnion)
          ScToSp_DD=transform_matrix(tNow,&                 
               Grid_C(SC_)%TypeCoord, Grid_C(SP_)%TypeCoord)
          call exchange_lines(SC_)
       end if
       ! put the lower boundary of the domain in SC to SP
       call SP_put_r_min(Grid_C(SC_)%Coord1_I(1))
    end if

    if(use_comp(IH_))then
       ! Set pair IH-SP
       call set_couple_var_info(IH_, SP_)
       call set_standard_grid_descriptor(IH_,GridDescriptor=&
            IH_GridDescriptor)
       call init_router(IH_GridDescriptor,SP_GridDescriptor,&
            RouterIhSp,nMappedPointIndex=nAux)
       call set_standard_grid_descriptor(IH_LineDD,GridDescriptor=&
            IH_LineGridDesc)
       if(is_proc(IH_))call set_local_gd(&
            iProc = i_proc(), &
            GridDescriptor = IH_LineGridDesc, &
            LocalGD = IH_LocalLineGD)
       call init_router(IH_LineGridDesc, SP_GridDescriptor, RouterLineIhSp,&
            nMappedPointIndex=0)
       if(RouterIhSp%IsProc)then
          call IH_synchronize_refinement(RouterIhSp%iProc0Source,&
               RouterIhSp%iCommUnion)
          IhToSp_DD=transform_matrix(tNow,&                 
               Grid_C(IH_)%TypeCoord, Grid_C(SP_)%TypeCoord)
          call exchange_lines(IH_)
       end if
    end if
  contains
    !================================================================    
    subroutine exchange_lines(iMHComp)
      ! MH extracts and sends field lines requested by SP;
      !----------------------------------------------------------------
      ! index of MH component
      integer, intent(in):: iMHComp
      !----------------------------------------------------------------
      ! conversion matrix between SP and MH coordinates
      real:: Convert_DD(3,3)
      ! request coordinates, one per line
      real, pointer:: CoordMisc_DI(:,:)
      ! number of particles per line
      integer,allocatable:: nParticleAtLine_I(:)
      ! requested variables
      integer:: nVar
      character(len=100):: NameVar
      ! particle data
      real, allocatable:: Particle_II(:,:)
      ! field line index in particle data
      integer:: iFLIndex
      ! MPI
      integer:: MH_iProcFrom, SP_iProcTo
      integer:: iProcTo_I(1), iProcFrom_I(1)
      integer:: nParticleThisProc
      integer, allocatable:: nParticleRecv_I(:), nParticleSend_I(:)
      integer, allocatable:: iStatus_II(:,:), iRequestS_I(:), iRequestR_I(:)
      integer:: nRequestS, nRequestR
      integer:: iTag = 0
      real, allocatable:: BuffRecv_I(:), BuffSend_I(:)
      ! loop variables
      integer:: iLine, iBuff, iParticle
      !----------------------------------------------------------------
      select case(iMHComp)
      case(SC_)
         if(is_proc(SP_))&
              call set_semi_router_from_target(&
              GridDescriptorSource  = SC_GridDescriptor, &
              GridDescriptorTarget  = SP_LocalGD, &
              Router                = RouterScSp, &
              n_interface_point_in_block = SP_n_particle,&
              interface_point_coords= SP_interface_point_coords_for_sc, &
              mapping               = mapping_sp_to_sc, &
              interpolate           = interpolation_amr_gc)
         call synchronize_router_target_to_source(RouterScSp)
         if(is_proc(SC_))then
            nLength = nlength_buffer_source(RouterScSp)
            call SC_extract_line(&
                 nLine           = nLength,                                   &
                 XyzOrigin_DI    = &
                 RouterScSp%BufferSource_II(1:nDim,1:nLength),                &
                 iTraceMode      = iInterfaceOrigin,                          &
                 nIndex          = nAux,                                      &
                 iIndexOrigin_II = &
                 nint(RouterScSp%BufferSource_II(nDim+1:nDim+nAux,1:nLength)),&
                 RSoftBoundary   =  RSc,                                      &
                 UseInputInGenCoord = .true.)
         end if
         if(is_proc(SC_))then
            call set_semi_router_from_source(&
                 GridDescriptorSource = SC_LocalLineGD,     &
                 GridDescriptorTarget = SP_GridDescriptor,  &
                 Router               = RouterLineScSp,     &
                 n_interface_point_in_block = SC_n_particle,&
                 interface_point_coords=SC_line_interface_point,&
                 mapping              = mapping_line_sc_to_sp)
         end if
         call synchronize_router_source_to_target(RouterLineScSp)
         if(is_proc(SP_))then
            call update_semi_router_at_target(&
                 RouterLineScSp, SP_GridDescriptor)
         end if
         call global_message_pass(RouterLineScSp, &
              nVar = 3, &
              fill_buffer = SC_get_line_for_sp_and_transform, &
              apply_buffer= SP_put_line_from_mh)
         if(is_proc(SP_))&
              call set_semi_router_from_target(&
              GridDescriptorSource  = SC_GridDescriptor, &
              GridDescriptorTarget  = SP_LocalGD, &
              Router                = RouterScSp, &
              n_interface_point_in_block = SP_n_particle,&
              interface_point_coords= SP_interface_point_coords_for_sc, &
              mapping               = mapping_sp_to_sc, &
              interpolate           = interpolation_amr_gc)
         call synchronize_router_target_to_source(RouterScSp)
         if(is_proc(SC_))then
            call update_semi_router_at_source(RouterScSp,&
                 SC_GridDescriptor,interpolation_amr_gc)
         end if

         call global_message_pass(RouterScSp, &
              nVar = nVarBuffer, &
              fill_buffer = SC_get_for_sp_and_transform, &
              apply_buffer= SP_put_from_mh)
      case(IH_)
         if(is_proc(SP_))&
              call set_semi_router_from_target(&
              GridDescriptorSource  = IH_GridDescriptor, &
              GridDescriptorTarget  = SP_LocalGD, &
              Router                = RouterIHSp, &
              n_interface_point_in_block = SP_n_particle,&
              interface_point_coords= SP_interface_point_coords_for_ih, &
              mapping               = mapping_sp_to_IH, &
              interpolate           = interpolation_amr_gc) 
         call synchronize_router_target_to_source(RouterIHSp)
         if(is_proc(IH_))then
            nLength = nlength_buffer_source(RouterIhSp)
            call IH_extract_line(&
                 nLine           = nLength,                                   &
                 XyzOrigin_DI    = &
                 RouterIhSp%BufferSource_II(1:nDim,1:nLength),                &
                 iTraceMode      = iInterfaceEnd,                             &
                 nIndex          = nAux,                                      &
                 iIndexOrigin_II = &
                 nint(RouterIhSp%BufferSource_II(nDim+1:nDim+nAux,1:nLength)),&
                 RSoftBoundary   =  RIh,                                      &
                 UseInputInGenCoord = .true.)
         end if
         if(is_proc(IH_))then
            call set_semi_router_from_source(&
                 GridDescriptorSource = IH_LocalLineGD,         &
                 GridDescriptorTarget = SP_GridDescriptor,      &
                 Router               = RouterLineIhSp,         &
                 n_interface_point_in_block = IH_n_particle,    &
                 interface_point_coords=IH_line_interface_point,&
                 mapping              = mapping_line_ih_to_sp)
         end if
         call synchronize_router_source_to_target(RouterLineIhSp)
         if(is_proc(SP_))then
            call update_semi_router_at_target(&
                 RouterLineIhSp, SP_GridDescriptor)
         end if
         call global_message_pass(RouterLineIhSp, &
              nVar = 3, &
              fill_buffer = IH_get_line_for_sp_and_transform, &
              apply_buffer= SP_put_line_from_mh)
         if(is_proc(SP_))&
              call set_semi_router_from_target(&
              GridDescriptorSource  = IH_GridDescriptor, &
              GridDescriptorTarget  = SP_LocalGD, &
              Router                = RouterIhSp, &
              n_interface_point_in_block = SP_n_particle,&
              interface_point_coords= SP_interface_point_coords_for_ih, &
              mapping               = mapping_sp_to_ih, &
              interpolate           = interpolation_amr_gc)
         call synchronize_router_target_to_source(RouterIhSp)
         if(is_proc(IH_))then
            call update_semi_router_at_source(RouterIhSp,&
                 IH_GridDescriptor,interpolation_amr_gc)
         end if

         call global_message_pass(RouterIhSp, &
              nVar = nVarBuffer, &
              fill_buffer = IH_get_for_sp_and_transform, &
              apply_buffer= SP_put_from_mh)
      end select
    end subroutine exchange_lines

  end subroutine couple_mh_sp_init
  !==================================================================!

  subroutine mapping(iCompIn, iCompOut, nDimIn, CoordIn_D, nDimOut, CoordOut_D)
    ! mapping from generalized coordinates in CompIn 
    ! to generalized coordinates in CompOut
    use ModCoordTransform, ONLY: xyz_to_rlonlat, rlonlat_to_xyz
    integer, intent(in) :: iCompIn
    integer, intent(in) :: iCompOut
    integer, intent(in) :: nDimIn
    real,    intent(in) :: CoordIn_D(nDimIn)
    integer, intent(in) :: nDimOut
    real,    intent(out):: CoordOut_D(nDimOut)

    character(len=100):: TypeGeometryIn, TypeGeometryOut
    real:: XyzTemp_D(nDimOut), CoordTemp_D(nDimIn)
    real:: Convert_DD(nDimIn, nDimOut)
    character(len=*), parameter:: NameSub='CON_couple_mh_sp:mapping'
    !------------------------------------------------------------
    if(nDimIn /= 3 .or. nDimOut /= 3)&
         call CON_stop(NameSub//': MH or SP component is not 3D')
    ! convert from geometry input type
    TypeGeometryIn = Grid_C(iCompIn)%TypeGeometry
    if(index(TypeGeometryIn, 'spherical_lnr') > 0 )then
       ! convert log(radius) to radius first
       CoordTemp_D = CoordIn_D
       CoordTemp_D(1) = exp(CoordTemp_D(1))
       call rlonlat_to_xyz(CoordTemp_D, XyzTemp_D)
    elseif( index(TypeGeometryIn, 'spherical') > 0 )then
       call rlonlat_to_xyz(CoordIn_D, XyzTemp_D)
    elseif(index(TypeGeometryIn, 'cartesian') > 0 )then
       XyzTemp_D = CoordIn_D
    else
       call CON_stop(NameSub//&
            ': unkown type of geometry '//trim(TypeGeometryIn))
    end if

    ! matrix for cartesian transform  between components
    Convert_DD = transform_matrix(tNow, &
         Grid_C(iCompIn)%TypeCoord,  Grid_C(iCompOut)%TypeCoord)

    ! geometry of iCompOut component
    TypeGeometryOut = Grid_C(iCompOut)%TypeGeometry
    ! rotate cartesian
    XyzTemp_D = matmul(Convert_DD, XyzTemp_D)
    ! convert to geometry output type
    if( index(TypeGeometryOut, 'spherical_lnr') > 0 )then
       call xyz_to_rlonlat(XyzTemp_D, CoordOut_D)
       ! convert radius to log(radius)
       if(CoordOut_D(1) > 0) CoordOut_D(1) = log(CoordOut_D(1))
    elseif( index(TypeGeometryOut, 'spherical') > 0 )then
       call xyz_to_rlonlat(XyzTemp_D, CoordOut_D)
    elseif(index(TypeGeometryOut, 'cartesian') > 0 )then
       CoordOut_D = XyzTemp_D
    else
       call CON_stop(NameSub//&
            ': unkown type of geometry '//trim(TypeGeometryOut))
    end if
  end subroutine mapping

  !==================================================================!
  subroutine mapping_sp_to_sc(nDimIn, XyzIn_D, nDimOut, CoordOut_D, &
       IsInterfacePoint)
    integer, intent(in) :: nDimIn
    real,    intent(in) :: XyzIn_D(nDimIn)
    integer, intent(in) :: nDimOut
    real,    intent(out):: CoordOut_D(nDimOut)
    logical, intent(out):: IsInterfacePoint
    !------------------------------------------
    IsInterfacePoint = .true.
    call mapping(SP_, SC_,nDimIn, XyzIn_D, nDimOut, CoordOut_D)
  end subroutine mapping_sp_to_sc
  !==================================================================!
  subroutine mapping_sp_to_ih(nDimIn, XyzIn_D, nDimOut, CoordOut_D, &
       IsInterfacePoint)
    integer, intent(in) :: nDimIn
    real,    intent(in) :: XyzIn_D(nDimIn)
    integer, intent(in) :: nDimOut
    real,    intent(out):: CoordOut_D(nDimOut)
    logical, intent(out):: IsInterfacePoint
    !------------------------------------------
    IsInterfacePoint = .true.
    call mapping(SP_,IH_,nDimIn, XyzIn_D, nDimOut, CoordOut_D)
  end subroutine mapping_sp_to_ih
  !==================================================================!
  subroutine mapping_line_sc_to_sp(nDimIn, XyzIn_D, nDimOut, CoordOut_D, &
       IsInterfacePoint)
    use CON_grid_descriptor
    integer, intent(in) :: nDimIn
    real,    intent(in) :: XyzIn_D(nDimIn)
    integer, intent(in) :: nDimOut
    real,    intent(out):: CoordOut_D(nDimOut)
    logical, intent(out):: IsInterfacePoint
    
    integer:: iIndex_I(2), iParticle
    !------------------------------------------
    IsInterfacePoint = .true.
    iParticle = nint(XyzIn_D(1))
    call SC_get_particle_indexes(iParticle, iIndex_I)
    CoordOut_D = xyz_grid_d(SP_GridDescriptor,iIndex_I(1),(/iIndex_I(2),1,1/))
  end subroutine mapping_line_sc_to_sp
  !==================================================================!
  subroutine mapping_line_ih_to_sp(nDimIn, XyzIn_D, nDimOut, CoordOut_D, &
       IsInterfacePoint)
    use CON_grid_descriptor
    integer, intent(in) :: nDimIn
    real,    intent(in) :: XyzIn_D(nDimIn)
    integer, intent(in) :: nDimOut
    real,    intent(out):: CoordOut_D(nDimOut)
    logical, intent(out):: IsInterfacePoint
    
    integer:: iIndex_I(2), iParticle
    !------------------------------------------
    IsInterfacePoint = .true.
    iParticle = nint(XyzIn_D(1))
    call IH_get_particle_indexes(iParticle, iIndex_I)
    CoordOut_D = xyz_grid_d(SP_GridDescriptor,iIndex_I(1),(/iIndex_I(2),1,1/))
  end subroutine mapping_line_ih_to_sp
  !==================================================================!
  subroutine mapping_sc_to_sp(nDimIn, XyzIn_D, nDimOut, CoordOut_D, &
       IsInterfacePoint)
    integer, intent(in) :: nDimIn
    real,    intent(in) :: XyzIn_D(nDimIn)
    integer, intent(in) :: nDimOut
    real,    intent(out):: CoordOut_D(nDimOut)
    logical, intent(out):: IsInterfacePoint
    !------------------------------------------
    IsInterfacePoint = .true.
    call mapping(SC_, SP_,nDimIn, XyzIn_D, nDimOut, CoordOut_D)
  end subroutine mapping_sc_to_sp
  !==================================================================!
  subroutine mapping_ih_to_sp(nDimIn, XyzIn_D, nDimOut, CoordOut_D, &
       IsInterfacePoint)
    integer, intent(in) :: nDimIn
    real,    intent(in) :: XyzIn_D(nDimIn)
    integer, intent(in) :: nDimOut
    real,    intent(out):: CoordOut_D(nDimOut)
    logical, intent(out):: IsInterfacePoint
    !------------------------------------------
    IsInterfacePoint = .true.
    call mapping(IH_,SP_,nDimIn, XyzIn_D, nDimOut, CoordOut_D)
  end subroutine mapping_ih_to_sp
  !=================================================================!
  subroutine SP_put_scatter_from_mh(nData, Coord_DI, iIndex1_I,&
       iIndex2_I)
    integer, intent(in):: nData
    real,    intent(in):: Coord_DI(nDim, nData)
    integer, intent(in):: iIndex1_I(nData)
    integer, intent(in):: iIndex2_I(nData)

    integer:: iIndex_II(4, nData)
    !--------------------------------------------------------
    iIndex_II(1,:) = iIndex1_I
    iIndex_II(2,:) = 1
    iIndex_II(3,:) = 1
    iIndex_II(4,:) = iIndex2_I
    call SP_put_line(nData, Coord_DI, iIndex_II)
  end subroutine SP_put_scatter_from_mh
  !==================================================================!
  subroutine SP_put_line_from_mh(nPartial,&
       iPutStart,&
       Put,&
       Weight,&
       DoAdd,&
       Buff_I,nVar)
    integer,intent(in)::nPartial,iPutStart,nVar
    type(IndexPtrType),intent(in)::Put
    type(WeightPtrType),intent(in)::Weight
    logical,intent(in)::DoAdd
    real,dimension(nVar),intent(in)::Buff_I
    
    real:: Buff_II(nVar, 1)
    integer:: iIndex_II(4,1)
    !----------------------------------------
    Buff_II(:,1)   = Buff_I
    iIndex_II(:,1) = Put%iCB_II(1:4,iPutStart)
    call SP_put_line(1, Buff_II, iIndex_II)
  end subroutine SP_put_line_from_mh
  !==================================================================!
  !^CMP IF IH BEGIN
  subroutine couple_ih_sp(DataInputTime)     

    use CON_global_message_pass

    real,intent(in)::DataInputTime
    real,dimension(3)::Xyz_D
    integer:: nLength
    !-------------------------------------------------------------------------
    if(.not.RouterIhSp%IsProc)return

    tNow=DataInputTime
    if(is_proc(SP_))call SP_put_input_time(DataInputTime)
    IhToSp_DD=transform_matrix(tNow,&
         Grid_C(IH_)%TypeCoord, Grid_C(SP_)%TypeCoord)
    ScToIh_DD=transform_matrix(tNow,&                   !^CMP IF SC
         Grid_C(SC_)%TypeCoord, Grid_C(IH_)%TypeCoord)  !^CMP IF SC


    call IH_synchronize_refinement(RouterIhSp%iProc0Source,&
         RouterIhSp%iCommUnion)

    if(is_proc(IH_))then
       call set_semi_router_from_source(&
            GridDescriptorSource = IH_LocalLineGD,         &
            GridDescriptorTarget = SP_GridDescriptor,      &
            Router               = RouterLineIhSp,         &
            n_interface_point_in_block = IH_n_particle,    &
            interface_point_coords=IH_line_interface_point,&
            mapping              = mapping_line_ih_to_sp)
    end if
    call synchronize_router_source_to_target(RouterLineIhSp)
    if(is_proc(SP_))then
       call update_semi_router_at_target(&
            RouterLineIhSp, SP_GridDescriptor)
    end if
    call global_message_pass(RouterLineIhSp, &
         nVar = 3, &
         fill_buffer = IH_get_line_for_sp_and_transform, &
         apply_buffer= SP_put_line_from_mh)
    if(is_proc(SP_))&
         call set_semi_router_from_target(&
         GridDescriptorSource  = IH_GridDescriptor, &
         GridDescriptorTarget  = SP_LocalGD, &
         Router                = RouterIHSp, &
         n_interface_point_in_block = SP_n_particle,&
         interface_point_coords= SP_interface_point_coords_for_ih, &
         mapping               = mapping_sp_to_ih, &
         interpolate           = interpolation_amr_gc)
    call synchronize_router_target_to_source(RouterIhSp)
    
    if(is_proc(IH_))then
       nLength = nlength_buffer_source(RouterIhSp)
       call IH_add_to_line(&
            nParticle = nLength,&
            Xyz_DI    =  RouterIhSp%BufferSource_II(&
            1:nDim, 1:nLength), &
            nIndex    = nAux,   &
            iIndex_II = nint(RouterIhSp%BufferSource_II(&
            nDim+1:nDim+nAux, 1:nLength)),&      
            UseInputInGenCoord = .true.,&
            DoReplace = .true.)
       call update_semi_router_at_source(RouterIhSp,&
            IH_GridDescriptor,interpolation_amr_gc)
    end if
    
    call global_message_pass(RouterIhSp, &
         nVar = nVarBuffer, &
         fill_buffer = IH_get_for_sp_and_transform, &
              apply_buffer= SP_put_from_mh)
    !    if(is_proc(SP_))then
    !       call SP_put_input_time(DataInputTime)
    !    end if
    !^CMP IF SC BEGIN
    !This coupler is performed after SC-SP coupling, so that 
    !on SP the updated coordinates are available for those
    !points which passed from SC to IH

  end subroutine couple_ih_sp
  !==================================================================
  logical function is_in_ih(Xyz_D)
    real,dimension(:),intent(in)::Xyz_D
    real:: R2
    R2 = dot_product(Xyz_D,Xyz_D)
    is_in_ih=R2>=rBoundIh**2.and.&
         all(Xyz_D < xyz_max_d(IH_)).and.all(Xyz_D >= xyz_min_d(IH_))
  end function is_in_ih
  !==================================================================!        
  subroutine IH_get_for_sp_and_transform(&
       nPartial,iGetStart,Get,w,State_V,nVar)

    integer,intent(in)::nPartial,iGetStart,nVar
    type(IndexPtrType),intent(in)::Get
    type(WeightPtrType),intent(in)::w
    real,dimension(nVar),intent(out)::State_V
    integer:: iVarBx, iVarBz
    !------------------------------------------------------------
    ! get buffer with variables
    call IH_get_for_sp(&
         nPartial,iGetStart,Get,w,State_V,nVar)
    ! indices of variables 
    iVarBx = iVar_V(BxCouple_)
    iVarBz = iVar_V(BzCouple_)
    ! perform transformation before returning
    State_V(iVarBx:iVarBz)=matmul(IhToSp_DD,State_V(iVarBx:iVarBz))
  end subroutine IH_get_for_sp_and_transform
  !==================================================================!        
  subroutine IH_get_line_for_sp_and_transform(&
       nPartial,iGetStart,Get,w,State_V,nVar)
    use ModCoordTransform, ONLY: xyz_to_rlonlat
    integer,intent(in)::nPartial,iGetStart,nVar
    type(IndexPtrType),intent(in)::Get
    type(WeightPtrType),intent(in)::w
    real,dimension(nVar),intent(out)::State_V
    !------------------------------------------------------------
    ! get buffer with variables
    call IH_get_particle_coords(Get%iCB_II(1,iGetStart),State_V)
    ! perform transformation before returning
    State_V = matmul(IhToSp_DD,State_V)
  end subroutine IH_get_line_for_sp_and_transform
  !^CMP END IH
  !=========================================================================
  !^CMP IF SC BEGIN
  subroutine couple_sc_sp(DataInputTime)
    use CON_global_message_pass

    real,intent(in)::DataInputTime
    integer:: nLength
    !-------------------------------------------------------
    if(.not.RouterScSp%IsProc)return

    tNow=DataInputTime
    if(is_proc(SP_))call SP_put_input_time(DataInputTime)

    ! IMPORTANT: 
    ! couple_sc_sp is called BEFORE couple_ih_sp; 
    ! save the current state as old,
    ! separate subroutine is used in order to avoid intersections 
    ! as fluid elements transfer from SC to IH
    if(is_proc(SP_))call SP_copy_old_state
    
    ScToSp_DD=transform_matrix(tNow,&
         Grid_C(SC_)%TypeCoord, Grid_C(SP_)%TypeCoord)

    call SC_synchronize_refinement(RouterScSp%iProc0Source,&
         RouterScSp%iCommUnion)
    if(is_proc(SC_))then
       call set_semi_router_from_source(&
            GridDescriptorSource = SC_LocalLineGD,         &
            GridDescriptorTarget = SP_GridDescriptor,      &
            Router               = RouterLineScSp,         &
            n_interface_point_in_block = SC_n_particle,    &
            interface_point_coords=SC_line_interface_point,&
            mapping              = mapping_line_sc_to_sp)
    end if
    call synchronize_router_source_to_target(RouterLineScSp)
    if(is_proc(SP_))then
       call update_semi_router_at_target(&
            RouterLineScSp, SP_GridDescriptor)
    end if
    call global_message_pass(RouterLineScSp, &
         nVar = 3, &
         fill_buffer = SC_get_line_for_sp_and_transform, &
         apply_buffer= SP_put_line_from_mh)
    if(is_proc(SP_))&
         call set_semi_router_from_target(&
         GridDescriptorSource  = SC_GridDescriptor, &
         GridDescriptorTarget  = SP_LocalGD, &
         Router                = RouterScSp, &
         n_interface_point_in_block = SP_n_particle,&
         interface_point_coords= SP_interface_point_coords_for_sc, &
         mapping               = mapping_sp_to_sc, &
         interpolate           = interpolation_amr_gc)
    call synchronize_router_target_to_source(RouterScSp)
    if(is_proc(SC_))then
       call update_semi_router_at_source(RouterScSp,&
            SC_GridDescriptor,interpolation_amr_gc)
    end if
    call global_message_pass(RouterScSp, &
         nVar = nVarBuffer, &
         fill_buffer = SC_get_for_sp_and_transform, &
         apply_buffer= SP_put_from_mh)
    !    if(is_proc(SP_))then
    !       call SP_put_input_time(DataInputTime)  
    !       call transform_to_sp_from(SC_)
    !    end if
  end subroutine couple_sc_sp
  !-------------------------------------------------------------------------
  logical function is_in_sc(Xyz_D)
    real,dimension(:),intent(in)::Xyz_D
    real::R2
    real,save:: RSCMin2 = -1
    real,save:: RSCMax2 = -1
    if(RSCMin2 == -1) RSCMin2 = dot_product(exp(xyz_min_d(SC_)),(/1,0,0/))**2
    if(RSCMax2 == -1) RSCMax2 = dot_product(exp(xyz_max_d(SC_)),(/1,0,0/))**2
    R2=dot_product(Xyz_D,Xyz_D)
    if(use_comp(IH_))then            !^CMP IF IH BEGIN
       is_in_sc=R2>=rBoundSc**2.and.R2<rBoundIh**2.and.&
            R2<RSCMax2.and.R2>=RSCMin2
    else                             !^CMP END IH
       is_in_sc=R2>=rBoundSc**2.and.&
            R2<RSCMax2.and.R2>=RSCMin2
    end if                           !^CMP IF IH
  end function is_in_sc
  !--------------------------------------------------------------------------
  subroutine SC_get_for_sp_and_transform(&
       nPartial,iGetStart,Get,w,State_V,nVar)

    integer,intent(in)::nPartial,iGetStart,nVar
    type(IndexPtrType),intent(in)::Get
    type(WeightPtrType),intent(in)::w
    real,dimension(nVar),intent(out)::State_V
    integer:: iVarBx, iVarBz
    !------------------------------------------------------------
    ! get buffer with variables
    call SC_get_for_sp(&
         nPartial,iGetStart,Get,w,State_V,nVar)
    ! indices of variables 
    iVarBx = iVar_V(BxCouple_)
    iVarBz = iVar_V(BzCouple_)
    ! perform transformation before returning
    State_V(iVarBx:iVarBz)=matmul(ScToSp_DD,State_V(iVarBx:iVarBz))
  end subroutine SC_get_for_sp_and_transform
  !=========================================================================
  subroutine SC_get_line_for_sp_and_transform(&
       nPartial,iGetStart,Get,w,State_V,nVar)
    use ModCoordTransform, ONLY: xyz_to_rlonlat
    integer,intent(in)::nPartial,iGetStart,nVar
    type(IndexPtrType),intent(in)::Get
    type(WeightPtrType),intent(in)::w
    real,dimension(nVar),intent(out)::State_V
    !------------------------------------------------------------
    ! get buffer with variables
    call SC_get_particle_coords(Get%iCB_II(1,iGetStart),State_V)
    ! perform transformation before returning
    State_V = matmul(ScToSp_DD,State_V)
  end subroutine SC_get_line_for_sp_and_transform
  !==================================================================!        
  !^CMP END SC
end Module CON_couple_mh_sp
