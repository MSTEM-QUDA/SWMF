!  Copyright (C) 2002 Regents of the University of Michigan,
!  portions used with permission
!  For more information, see http://csem.engin.umich.edu/tools/swmf

module IH_wrapper
  use CON_domain_decomposition
  ! Wrapper for an "empty" Inner Heliosphere (IH) component
  use CON_coupler,             ONLY: IH_, GridType, LocalGridType
  implicit none

  private ! except

  ! CON wrapper
  public:: IH_set_param
  public:: IH_init_session
  public:: IH_run
  public:: IH_save_restart
  public:: IH_finalize

  ! Global buffer coupling
  public:: IH_get_for_global_buffer
  public:: IH_xyz_to_coord, IH_coord_to_xyz

  ! Coupling toolkit
  public:: IH_synchronize_refinement
  public:: IH_get_for_mh
  public:: IH_get_for_mh_with_xyz
  public:: IH_put_from_mh
  public:: IH_is_coupled_block
  public:: IH_interface_point_coords
  public:: IH_n_particle
  Character(len=3),    public :: TypeCoordSource    ! Coords of coupled model
  real,                public :: SourceToIH_DD(3,3) ! Transformation matrrix
  real,                public :: TimeMhToIH = -1.0  ! Time of coupling

  type(GridType),      public :: IH_Grid            ! Grid (MHD data)
  type(GridType),      public :: IH_LineGrid        ! Global GD for lines
  type(LocalGridType), public :: IH_LocalGrid       ! Local GD (MHD data)
  type(LocalGridType), public :: IH_LocalLineGrid   ! Local GD for lines)


  ! Coupling with SC
  public:: IH_set_buffer_grid_get_info
  public:: IH_save_global_buffer
  public:: IH_match_ibc

  ! Point coupling
  public:: IH_get_grid_info
  public:: IH_find_points

  ! Coupling with SP
  public:: IH_check_ready_for_sp
  public:: IH_extract_line
  public:: IH_put_particles
  public:: IH_get_particle_indexes
  public:: IH_get_particle_coords

  ! Coupling with GM
  public:: IH_get_for_gm

  ! Coupling with PT
  public:: IH_get_for_pt
  public:: IH_put_from_pt
  public:: IH_get_for_pt_dt

  ! Coupling with EE (for SC)
  public:: IH_get_for_ee
  public:: IH_put_from_ee

contains
  !============================================================================
  subroutine IH_set_param(CompInfo, TypeAction)

    use CON_comp_info

    ! Arguments
    type(CompInfoType), intent(inout):: CompInfo   ! Information for this comp.
    character (len=*), intent(in)    :: TypeAction ! What to do
    character(len=*), parameter:: NameSub = 'IH_set_param'
    !--------------------------------------------------------------------------
    select case(TypeAction)
    case('VERSION')
       call put(CompInfo,&
            Use        =.false., &
            NameVersion='Empty', &
            Version    =0.0)

    case default
       call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
    end select

  end subroutine IH_set_param
  !============================================================================

  subroutine IH_init_session(iSession, TimeSimulation)

    integer,  intent(in) :: iSession         ! session number (starting from 1)
    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter:: NameSub = 'IH_init_session'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_init_session
  !============================================================================

  subroutine IH_finalize(TimeSimulation)

    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter:: NameSub = 'IH_finalize'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_finalize
  !============================================================================

  subroutine IH_save_restart(TimeSimulation)

    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter:: NameSub = 'IH_save_restart'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_save_restart
  !============================================================================

  subroutine IH_run(TimeSimulation,TimeSimulationLimit)

    real, intent(inout):: TimeSimulation   ! current time of component

    real, intent(in):: TimeSimulationLimit ! simulation time not to be exceeded

    character(len=*), parameter:: NameSub = 'IH_run'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_run
  !============================================================================
  subroutine IH_get_grid_info(nDimOut, iGridOut, iDecompOut)

    integer, intent(out):: nDimOut    ! grid dimensionality
    integer, intent(out):: iGridOut   ! grid index (increases with AMR)
    integer, intent(out):: iDecompOut ! decomposition index

    character(len=*), parameter:: NameSub = 'IH_get_grid_info'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_get_grid_info
  !============================================================================
  subroutine IH_coord_to_xyz(CoordIn_D, XyzOut_D)
    real, intent(in) :: CoordIn_D(3)
    real, intent(out):: XyzOut_D( 3)
    character(len=*), parameter:: NameSub = 'IH_coord_to_xyz'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_coord_to_xyz
  !============================================================================
  subroutine IH_xyz_to_coord(XyzIn_D, CoordOut_D)
    real,             intent(in ) :: XyzIn_D(3)
    real,             intent(out) :: CoordOut_D(3)
    character(len=*), parameter:: NameSub = 'IH_xyz_to_coord'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_xyz_to_coord
  !============================================================================
  subroutine IH_find_points(nDimIn, nPoint, Xyz_DI, iProc_I)

    integer, intent(in) :: nDimIn                ! dimension of position vectors
    integer, intent(in) :: nPoint                ! number of positions
    real,    intent(in) :: Xyz_DI(nDimIn,nPoint) ! positions
    integer, intent(out):: iProc_I(nPoint)       ! processor owning position

    ! Find array of points and return processor indexes owning them
    ! Could be generalized to return multiple processors...

    character(len=*), parameter:: NameSub = 'IH_find_points'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_find_points
  !============================================================================

  subroutine IH_synchronize_refinement(iProc0,iCommUnion)

    integer, intent(in) ::iProc0,iCommUnion

    character(len=*), parameter:: NameSub = 'IH_synchronize_refinement'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_synchronize_refinement
  !============================================================================

  subroutine IH_get_for_gm(&
       nPartial,iGetStart,Get,W,State_V,nVar,TimeCoupling)

    use CON_router, ONLY: IndexPtrType, WeightPtrType

    integer,intent(in)::nPartial,iGetStart,nVar
    type(IndexPtrType),intent(in)::Get
    type(WeightPtrType),intent(in)::W
    real,dimension(nVar),intent(out)::State_V
    real,intent(in)::TimeCoupling

    character(len=*), parameter:: NameSub = 'IH_get_for_gm'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_get_for_gm
  !============================================================================
  logical function IH_is_coupled_block(iBlock)
    integer, intent(in) :: iBlock
    character(len=*), parameter:: NameSub = 'IH_is_coupled_block'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end function IH_is_coupled_block
  !============================================================================
  subroutine IH_interface_point_coords(nDim, Xyz_D, nIndex, iIndex_I, &
       IsInterfacePoint)
    integer,intent(in)   :: nDim
    real,   intent(inout):: Xyz_D(nDim)
    integer,intent(in)   :: nIndex
    integer,intent(inout):: iIndex_I(nIndex)
    logical,intent(out)  :: IsInterfacePoint
    character(len=*), parameter:: NameSub = 'IH_interface_point_coords'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_interface_point_coords
  !============================================================================
  subroutine IH_get_for_mh(&
       nPartial,iGetStart,Get,W,State_V,nVar)

    use CON_router, ONLY: IndexPtrType, WeightPtrType

    integer,intent(in)              ::nPartial,iGetStart,nVar
    type(IndexPtrType),intent(in)   ::Get
    type(WeightPtrType),intent(in)  ::W
    real,dimension(nVar),intent(out)::State_V

    character(len=*), parameter:: NameSub = 'IH_get_for_mh'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_get_for_mh
  !============================================================================
  subroutine IH_get_for_mh_with_xyz(&
       nPartial,iGetStart,Get,W,State_V,nVar)

    use CON_router, ONLY: IndexPtrType, WeightPtrType

    integer,intent(in)               :: nPartial,iGetStart,nVar
    type(IndexPtrType),intent(in)    :: Get
    type(WeightPtrType),intent(in)   :: W
    real,dimension(nVar),intent(out) ::State_V

    character(len=*), parameter:: NameSub = 'IH_get_for_mh_with_xyz'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_get_for_mh_with_xyz
  !============================================================================
  subroutine IH_check_ready_for_sp(IsReady)
    logical, intent(out):: IsReady
    character(len=*), parameter:: NameSub = 'IH_check_ready_for_sp'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_check_ready_for_sp
  !============================================================================
  subroutine IH_get_particle_indexes(iParticle, iIndex_I)
    integer, intent(in) :: iParticle
    integer, intent(out):: iIndex_I(2)
    character(len=*), parameter:: NameSub = 'IH_get_particle_indexes'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_get_particle_indexes
  !============================================================================
  subroutine IH_get_particle_coords(iParticle, Xyz_D)
    integer, intent(in) :: iParticle
    real,    intent(out):: Xyz_D(3)
    character(len=*), parameter:: NameSub = 'IH_get_particle_coords'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_get_particle_coords
  !============================================================================
  subroutine IH_extract_line(Xyz_DI, iTraceMode, &
       iIndex_II, RSoftBoundary)
    real,             intent(in) :: Xyz_DI(:, :)
    integer,          intent(in) :: iTraceMode
    integer,          intent(in) :: iIndex_II(:,:)
    real,             intent(in) :: RSoftBoundary
    character(len=*), parameter:: NameSub = 'IH_extract_line'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_extract_line
  !============================================================================
  subroutine IH_put_particles(Xyz_DI, iIndex_II)
    real,    intent(in) :: Xyz_DI(:, :)
    integer, intent(in) :: iIndex_II(:,:)
    character(len=*), parameter:: NameSub = 'IH_put_particles'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_put_particles
  !============================================================================
  subroutine IH_put_from_mh(nPartial,&
       iPutStart,&
       Put,&
       Weight,&
       DoAdd,&
       StateSI_V,&
       nVar)
    use CON_router,    ONLY: IndexPtrType, WeightPtrType

    integer,intent(in)::nPartial,iPutStart,nVar
    type(IndexPtrType),intent(in)::Put
    type(WeightPtrType),intent(in)::Weight
    logical,intent(in)::DoAdd
    real,dimension(nVar),intent(in)::StateSI_V

    character(len=*), parameter:: NameSub = 'IH_put_from_mh'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_put_from_mh
  !============================================================================
  subroutine IH_match_ibc

    character(len=*), parameter:: NameSub = 'IH_match_ibc'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_match_ibc
  !============================================================================
  subroutine IH_set_buffer_grid_get_info(&
       nR, nPhi, nTheta, BufferMinMax_DI)

    integer, intent(out)    :: nR, nPhi, nTheta
    real, intent(out)       :: BufferMinMax_DI(3,2)

    ! ---------------------------------------------------------------

    character(len=*), parameter:: NameSub = 'IH_set_buffer_grid_get_info'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_set_buffer_grid_get_info
  !============================================================================
  subroutine IH_save_global_buffer(nVar, nR, nLon, nLat, BufferIn_VG)

    integer,intent(in) :: nVar, nR, nLon, nLat
    real,intent(in)    :: BufferIn_VG(nVar, nR, 0:nLon+1, 0:nLat+1)

    character(len=*), parameter:: NameSub = 'IH_save_global_buffer'
    !--------------------------------------------------------------------------

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_save_global_buffer
  !============================================================================
  subroutine IH_get_for_global_buffer(&
       nR, nPhi,nTheta, BufferMinMax_DI, Buffer_VG)

    ! Buffer size and limits
    integer,intent(in) :: nR, nPhi, nTheta
    real, intent(in)   :: BufferMinMax_DI(3,2)

    ! State variables to be fiiled in all buffer grid points
    real, intent(out):: Buffer_VG(:,:,:,:)

    character(len=*), parameter:: NameSub = 'IH_get_for_global_buffer'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_get_for_global_buffer
  !============================================================================
  subroutine IH_get_for_pt(IsNew, NameVar, nVarIn, nDimIn, nPoint, Xyz_DI, &
       Data_VI)

    ! Get magnetic field data from IH to PT
    logical,          intent(in):: IsNew   ! true for new point array
    character(len=*), intent(in):: NameVar ! List of variables
    integer,          intent(in):: nVarIn  ! Number of variables in Data_VI
    integer,          intent(in):: nDimIn  ! Dimensionality of positions
    integer,          intent(in):: nPoint  ! Number of points in Xyz_DI

    real, intent(in) :: Xyz_DI(nDimIn,nPoint)  ! Position vectors
    real, intent(out):: Data_VI(nVarIn,nPoint) ! Data array

    character(len=*), parameter:: NameSub = 'IH_get_for_pt'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_get_for_pt
  !============================================================================

  subroutine IH_put_from_pt( &
       NameVar, nVar, nPoint, Data_VI, iPoint_I, Pos_DI)

    character(len=*), intent(inout):: NameVar ! List of variables
    integer,          intent(inout):: nVar    ! Number of variables in Data_VI
    integer,          intent(inout):: nPoint  ! Number of points in Pos_DI

    real,    intent(in), optional:: Data_VI(:,:)    ! Recv data array
    integer, intent(in), optional:: iPoint_I(nPoint)! Order of data
    real, intent(out), allocatable, optional:: Pos_DI(:,:) ! Position vectors

    character(len=*), parameter:: NameSub = 'IH_put_from_pt'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_put_from_pt
  !============================================================================
  subroutine IH_get_for_pt_dt(DtSi)
    real, intent(out) ::  DtSi
    character(len=*), parameter:: NameSub = 'IH_get_for_pt_dt'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_get_for_pt_dt
  !============================================================================

  subroutine IH_get_for_ee(IsNew, NameVar, nVarIn, nDimIn, nPoint, Xyz_DI, &
       Data_VI)

    ! This routine is actually for SC-EE coupling

    ! Interpolate Data_VI from SC at the list of positions Xyz_DI
    ! required by EE

    logical,          intent(in):: IsNew   ! true for new point array
    character(len=*), intent(in):: NameVar ! List of variables
    integer,          intent(in):: nVarIn  ! Number of variables in Data_VI
    integer,          intent(in):: nDimIn  ! Dimensionality of positions
    integer,          intent(in):: nPoint  ! Number of points in Xyz_DI

    real, intent(in) :: Xyz_DI(nDimIn,nPoint)  ! Position vectors
    real, intent(out):: Data_VI(nVarIn,nPoint) ! Data array

    character(len=*), parameter:: NameSub = 'IH_get_for_ee'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_get_for_ee
  !============================================================================

  subroutine IH_put_from_ee( &
       NameVar, nVarData, nPoint, Data_VI, iPoint_I, Pos_DI)

    ! This routine is actually for EE-SC coupling

    character(len=*), intent(inout):: NameVar ! List of variables
    integer,          intent(inout):: nVarData! Number of variables in Data_VI
    integer,          intent(inout):: nPoint  ! Number of points in Pos_DI

    real,    intent(in), optional:: Data_VI(:,:)    ! Recv data array
    integer, intent(in), optional:: iPoint_I(nPoint)! Order of data
    real, intent(out), allocatable, optional:: Pos_DI(:,:) ! Position vectors

    character(len=*), parameter:: NameSub = 'IH_put_from_ee'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_put_from_ee
  !============================================================================
  integer function IH_n_particle(iBlockLocal)
    integer, intent(in) :: iBlockLocal

    character(len=*), parameter:: NameSub = 'IH_n_particle'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end function IH_n_particle
  !============================================================================

end module IH_wrapper
!==============================================================================

