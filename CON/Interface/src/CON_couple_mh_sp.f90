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
       IH_get_line, IH_get_for_sp, IH_get_a_line_point      !^CMP IF IH

  use SC_wrapper, ONLY: SC_synchronize_refinement, &        !^CMP IF SC
       SC_get_line, SC_get_for_sp, SC_get_a_line_point      !^CMP IF SC

  use CON_global_message_pass
  use CON_axes

  use SP_wrapper, ONLY: &
       SP_put_from_mh, SP_put_input_time, SP_get_interface, &
       SP_put_line, SP_get_line_origin

  implicit none

  private !Except
  public::couple_mh_sp_init
  public::couple_ih_sp              !^CMP IF IH
  public::couple_sc_sp              !^CMP IF SC

  type(GridDescriptorType),save::SP_GridDescriptor !Target

  type(GridDescriptorType),save::IH_GridDescriptor !Source  !^CMP IF IH
  type(RouterType),save,private::RouterIhSp                 !^CMP IF IH

  type(GridDescriptorType),save::SC_GridDescriptor !Source  !^CMP IF SC
  type(RouterType),save,private::RouterScSp                 !^CMP IF SC

  logical,save::DoInit=.true.
  real,allocatable,dimension(:,:)::XyzTemp_DI

  real,dimension(:,:),pointer ::Xyz_DI
  logical,dimension(:),pointer :: Is_I
  integer,parameter::nPointMax=5000
  integer::nPoint=0
  integer::iPoint
  integer::iError
  real::bDxyz_I(1:6)!The interpolated values of full B and DXyz
  real::DsResolution,XyzLine_D(3)
  real,save::rBoundIh                !^CMP IF IH
  real,save::rBoundSc                !^CMP IF SC
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
    integer::nLine
    integer,allocatable:: nParticleAtLine_I(:)
    real,        pointer:: CoordMisc_DI(:,:)
    integer:: nVarSend, nVarRecv
    integer:: SP_iProcTo, SC_iProcFrom
    integer:: iProcTo_I(1), iProcFrom_I(1)
    integer:: nParticleThisProc, nParticleRecv, nParticleSend
    real, pointer:: Particle_II(:,:)
    real, allocatable:: BuffRecv_I(:), BuffSend_I(:)
    integer:: iLine, iBuff, iParticle, iTag
    integer:: iStatus_I(MPI_STATUS_SIZE)
    !----------------------------------------------------------------------
    if(.not.DoInit)return
    call CON_set_do_test(NameSub,DoTest,DoTestMe)
    DoInit=.false.
    !The initialization can be done only once

    call get_time(tSimulationOut=tNow)

    !\
    ! Set grid descriptors for components
    ! Initialize routers
    !/
    call set_standard_grid_descriptor(SP_,GridDescriptor=&
         SP_GridDescriptor)

    if(use_comp(SC_))then  
       ! Set pair SC-SP
       call set_standard_grid_descriptor(SC_,GridDescriptor=&
            SC_GridDescriptor)
       call init_router(SC_GridDescriptor,SP_GridDescriptor,&
            RouterScSp)
    end if

    if(use_comp(IH_))then
       ! Set pair IH-SP
       call set_standard_grid_descriptor(IH_,GridDescriptor=&
            IH_GridDescriptor)
       call init_router(IH_GridDescriptor,SP_GridDescriptor,&
            RouterIhSp)
    end if


    !\
    ! Write origin points for field lines into a global vector
    !/
    nLine = SP_GridDescriptor%DD%Ptr%nBlockAll
    call allocate_vector('SP_Xyz_DI',&
         SP_GridDescriptor%DD%Ptr%nDim, nLine)

    if(is_proc0(SP_))then
       call associate_with_global_vector(CoordMisc_DI,'SP_Xyz_DI')
       call SP_get_line_origin(CoordMisc_DI)
       nullify(CoordMisc_DI)
    end if

    call bcast_global_vector('SP_Xyz_DI',i_proc0(SP_),i_comm())


    if(is_proc(SC_))then
       !\
       ! Extract field lines at SC
       !/
       call associate_with_global_vector(CoordMisc_DI,'SP_Xyz_DI')
       SpToSc_DD = transform_matrix(tNow,&
         Grid_C(SP_)%TypeCoord, Grid_C(SC_)%TypeCoord)
       do iLine = 1, nLine
          CoordMisc_DI(:,iLine) = matmul(SpToSc_DD, CoordMisc_DI(:,iLine))
       end do
       allocate(nParticleAtLine_I(nLine))
       call SC_get_line(nLine, CoordMisc_DI, 'xx yy zz fl id', Particle_II)
       nullify(CoordMisc_DI)
       nVarSend = 5
       do iLine = 1, nLine
          nParticleAtLine_I(iLine) = count(nint(Particle_II(4,:))==iLine)
       end do
       nParticleThisProc = sum(nParticleAtLine_I)
       !\
       ! Send line to SP:
       ! on SC by index fl_ can find recepient on SP 
       ! (domain decomposition of SP is known everywhere)
       !/
       do SP_iProcTo = 0, n_proc(SP_)-1
          ! count how many points will be sent
          nParticleSend = sum(nParticleAtLine_I, &
               MASK = &
               SP_GridDescriptor%DD%Ptr%iDecomposition_II(PE_,:) == SP_iProcTo)
          ! translate proc at SP to global
          call MPI_Group_translate_ranks(&
               i_group(SP_), 1, (/SP_iProcTo/), &
               i_group(),            iProcTo_I, iError)
          ! send number of particles to be transfered
          call MPI_send(nParticleSend, 1, MPI_INTEGER, &
               iProcTo_I(1), iTag, i_comm(),iError)
          if(nParticleSend == 0) CYCLE
          ! prepare data
          if(allocated(BuffSend_I)) deallocate(BuffSend_I)
          allocate(BuffSend_I(nVarSend * nParticleSend))
          iBuff = 1
          do iParticle = 1, nParticleThisProc
             if(SP_GridDescriptor%DD%Ptr%iDecomposition_II(PE_,&
                  nint(Particle_II(4,iParticle)))/=SP_iProcTo) CYCLE
             BuffSend_I(iBuff:iBuff + nVarSend - 1) = Particle_II(:,iParticle)
             iBuff = iBuff + nVarSend - 1
          end do
          ! transfer data
          call MPI_send(BuffSend_I,nVarSend * nParticleSend, &
               MPI_DOUBLE, iProcTo_I(1), iTag, i_comm(), iError)
       end do
       
    end if


    if(is_proc(SP_))then
       !\
       ! Recv data from SC
       !/
       nVarRecv = 5
       do SC_iProcFrom = 0, n_proc(SC_)-1
          ! translate proc at SC to global
          call MPI_Group_translate_ranks(&
               i_group(SC_), 1, (/SC_iProcFrom/), &
               i_group(),            iProcFrom_I, iError)
          ! recv # of particles to be received
          call MPI_recv(nParticleRecv, 1, MPI_INTEGER,&
               iProcFrom_I(1), iTag, i_comm(), iStatus_I, iError)
          if(nParticleRecv==0)CYCLE
          ! recv data
          call MPI_recv(BuffRecv_I, nVarRecv*nParticleRecv, MPI_DOUBLE,&
               iProcFrom_I(1), iTag, i_comm(), iStatus_I, iError)
          !!!!!!!!!!!!!!!!!!
          ! CONVERSION HERE
          !!!!!!!!!!!!!!!!!!
          ! put data
          call SP_put_line(nParticleRecv,&
               reshape(BuffRecv_I,(/nVarRecv,nParticleRecv/)))
       end do
    end if

    !\
    ! find the interface points between SC and IH
    ! easier to do this at SP: each line has all of its particles at one proc
    !/
!    if(is_proc(SP_))then
!       call associate_with_global_vector(CoordMisc_DI,'SP_Xyz_DI')
!       call SP_get_interface(CoordMisc_DI)
!       ! collect all data on the SP root
!       call MPI_Reduce(&
!            CoordMisc_DI, CoordMisc_DI, SP_GridDescriptor%DD%Ptr%nDim*nLine, MPI_DOUBLE, &
!         MPI_SUM, 0, i_comm(SP_), iError)!i_proc0(SP_), i_comm(SP_), iError)

!       nullify(CoordMisc_DI)
!    end if
!    call bcast_global_vector('SP_Xyz_DI',i_proc0(SP_),i_comm())

  contains
  end subroutine couple_mh_sp_init
  !==================================================================!
  subroutine transform_to_sp_from(iComp)
    integer,intent(in)::iComp
    real,pointer,dimension(:,:)::SP_LocalXyz_DI
    logical,pointer,dimension(:)::Is_I
    integer::nU_I(2),i
    real,dimension(3,3)::MhToSp_DD
    character(LEN=2)::NameComp
    real::LengthRatio
    call get_comp_info(iComp,Name=NameComp)
    MhToSp_DD=transform_matrix(tNow,&
         Grid_C(iComp)%TypeCoord,&
         Grid_C(SP_)%TypeCoord)
    if(DoTest)write(*,*)'Transform SP coordinates from '//NameComp
    call associate_with_global_mask(Is_I,'SP_IsIn'//NameComp)
    call associate_with_global_vector(SP_LocalXyz_DI,'SP_XyzSP')
    nU_I=ubound(SP_LocalXyz_DI)
    if(DoTest)write(*,*)nU_I
    LengthRatio=Grid_C(iComp)%UnitX/Grid_C(SP_)%UnitX
    do i=1,nU_I(2)
       if(.not.Is_I(i))CYCLE
       SP_LocalXyz_DI(:,i)=matmul(MhToSp_DD,&
            point_state_v('SP_Xyz_DI',3,i))*LengthRatio
    end do
    nullify(SP_LocalXyz_DI,Is_I)
  end subroutine transform_to_sp_from

  !==================================================================
  !^CMP IF IH BEGIN
  subroutine couple_ih_sp(DataInputTime)     

    use CON_global_message_pass

    real,intent(in)::DataInputTime
    real,dimension(3)::Xyz_D
    !-------------------------------------------------------------------------

!    if(.not.RouterIhSp%IsProc)return
!
!    tNow=DataInputTime
!    IhToSp_DD=transform_matrix(tNow,&
!         Grid_C(IH_)%TypeCoord, Grid_C(SP_)%TypeCoord)
!    ScToIh_DD=transform_matrix(tNow,&                   !^CMP IF SC
!         Grid_C(SC_)%TypeCoord, Grid_C(IH_)%TypeCoord)  !^CMP IF SC
!
!
!    call IH_synchronize_refinement(RouterIhSp%iProc0Source,&
!         RouterIhSp%iCommUnion)
!    call bcast_global_vector('SP_Xyz_DI',&
!         RouterIhSp%iProc0Source,&
!         RouterIhSp%iCommUnion,&
!         'SP_IsInIH')
!    call set_router(& 
!         GridDescriptorSource=IH_GridDescriptor,&
!         GridDescriptorTarget=SP_GridDescriptor,&
!         Router=RouterIhSp,&
!         NameMappingVector='SP_Xyz_DI',&
!         NameMask='SP_IsInIH',&
!         interpolate=interpolation_fix_reschange)
!
!    if(is_proc(SP_))then
!       call SP_put_input_time(DataInputTime)
!       call transform_to_sp_from(IH_)
!    end if
!
!    call global_message_pass(RouterIhSp,&
!         nVar=8,&
!         fill_buffer=IH_get_for_sp_and_transform,&
!         apply_buffer=SP_put_from_mh)
!    !^CMP IF SC BEGIN
!    !This coupler is performed after SC-SP coupling, so that 
!    !on SP the updated coordinates are available for those
!    !points which passed from SC to IH
!
!    if(use_comp(SC_))then              
!       if(is_proc0(SP_))then
!          !Check the points which passed from SC to IH:
!          call associate_with_global_vector(Xyz_DI,'SP_Xyz_DI')
!          call associate_with_global_mask(Is_I,'SP_IsInIH')
!
!          do iPoint=1,nPoint
!             if(Is_I(iPoint))CYCLE
!             !Consider a point which before was   not in IH
!             Xyz_D=matmul(ScToIh_DD,Xyz_DI(:,iPoint))*&
!                  (Grid_C(SC_)%UnitX/Grid_C(IH_)%UnitX) 
!             if(is_in_ih(Xyz_D))& ! Now the point is in IH
!                  Xyz_DI(:,iPoint)=Xyz_D
!             !..that is why we convert it to IH coordinates
!          end do
!          nullify(Xyz_DI)
!          nullify(Is_I)
!       end if
!       call bcast_global_vector('SP_Xyz_DI',&
!            RouterIhSp%iProc0Target,&
!            RouterIhSp%iCommUnion)           !^CMP END SC
!    end if
!    call set_mask('SP_IsInIH','SP_Xyz_DI',is_in_ih)
  end subroutine couple_ih_sp
  !==================================================================
  logical function is_in_ih(Xyz_D)
    real,dimension(:),intent(in)::Xyz_D
    is_in_ih=dot_product(Xyz_D,Xyz_D)>=rBoundIh**2.and.&
         all(Xyz_D<=xyz_max_d(IH_)).and.all(Xyz_D>=xyz_min_d(IH_))
  end function is_in_ih
  !==================================================================!        
  subroutine IH_get_for_sp_and_transform(&
       nPartial,iGetStart,Get,w,State_V,nVar)

    integer,intent(in)::nPartial,iGetStart,nVar
    type(IndexPtrType),intent(in)::Get
    type(WeightPtrType),intent(in)::w
    real,dimension(nVar),intent(out)::State_V
    real,dimension(nVar+3)::State3_V
    integer, parameter :: Rho_=1, Ux_=2, Uz_=4, Bx_=5, Bz_=7,&
         BuffX_    =9,BuffZ_=11
    !------------------------------------------------------------
    call IH_get_for_sp(&
         nPartial,iGetStart,Get,w,State3_V,nVar+3)
    State_V=State3_V(1:nVar)

    State_V(Ux_:Uz_)=&
         transform_velocity(tNow,&
         State_V(Ux_:Uz_),&
         State3_V(BuffX_:BuffZ_),&
         Grid_C(IH_)%TypeCoord,Grid_C(SP_)%TypeCoord)

    State_V(Bx_:Bz_)=matmul(IhToSp_DD,State_V(Bx_:Bz_))
  end subroutine IH_get_for_sp_and_transform
  !^CMP END IH
  !=========================================================================
  !^CMP IF SC BEGIN
  subroutine couple_sc_sp(DataInputTime)
!    use CON_global_message_pass
!
    real,intent(in)::DataInputTime
!
!    if(.not.RouterScSp%IsProc)return
!
!    tNow=DataInputTime
!    ScToSP_DD=transform_matrix(tNow,&
!         Grid_C(SC_)%TypeCoord, Grid_C(SP_)%TypeCoord)
!
!    call SC_synchronize_refinement(RouterScSp%iProc0Source,&
!         RouterScSp%iCommUnion)
!    call bcast_global_vector('SP_Xyz_DI',&
!         RouterScSp%iProc0Source,&
!         RouterScSp%iCommUnion,&
!         'SP_IsInSC')
!    call set_router(& 
!         GridDescriptorSource=SC_GridDescriptor,&
!         GridDescriptorTarget=SP_GridDescriptor,&
!         Router=RouterScSp,&
!         NameMappingVector='SP_Xyz_DI',&
!         NameMask='SP_IsInSC',&
!         interpolate=interpolation_fix_reschange)
!    if(is_proc(SP_))then
!       call SP_put_input_time(DataInputTime)  
!       call transform_to_sp_from(SC_)
!    end if
!    call global_message_pass(RouterScSp,&
!         nVar=8,&
!         fill_buffer=SC_get_for_sp_and_transform,&
!         apply_buffer=SP_put_from_mh)
!    call set_mask('SP_IsInSC','SP_Xyz_DI',is_in_sc)
  end subroutine couple_sc_sp
  !-------------------------------------------------------------------------
  logical function is_in_sc(Xyz_D)
    real,dimension(:),intent(in)::Xyz_D
    real::R2
    R2=dot_product(Xyz_D,Xyz_D)
    if(use_comp(IH_))then            !^CMP IF IH BEGIN
       is_in_sc=R2>=rBoundSc**2.and.R2<rBoundIh**2
    else                             !^CMP END IH
       is_in_sc=R2>=rBoundSc**2.and.&
            all(Xyz_D<=xyz_max_d(SC_)).and.all(Xyz_D>=xyz_min_d(SC_))
    end if                           !^CMP IF IH
  end function is_in_sc
  !--------------------------------------------------------------------------
  subroutine SC_get_for_sp_and_transform(&
       nPartial,iGetStart,Get,w,State_V,nVar)

    integer,intent(in)::nPartial,iGetStart,nVar
    type(IndexPtrType),intent(in)::Get
    type(WeightPtrType),intent(in)::w
    real,dimension(nVar),intent(out)::State_V
    real,dimension(nVar+3)::State3_V
    integer, parameter :: Rho_=1, Ux_=2, Uz_=4, Bx_=5, Bz_=7,&
         BuffX_    =9,BuffZ_=11
    !------------------------------------------------------------
    call SC_get_for_sp(&
         nPartial,iGetStart,Get,w,State3_V,nVar+3)
    State_V=State3_V(1:nVar)

    State_V(Ux_:Uz_)=&
         transform_velocity(tNow,&
         State_V(Ux_:Uz_),&
         State3_V(BuffX_:BuffZ_),&
         Grid_C(SC_)%TypeCoord,Grid_C(SP_)%TypeCoord)

    State_V(Bx_:Bz_)=matmul(ScToSp_DD,State_V(Bx_:Bz_))
  end subroutine SC_get_for_sp_and_transform
  !=========================================================================
  !^CMP END SC
end Module CON_couple_mh_sp
