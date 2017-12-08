!  Copyright (C) 2002 Regents of the University of Michigan, 
!  portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf

module IH_wrapper
  use CON_domain_decomposition
  ! Wrapper for an "empty" Inner Heliosphere (IH) component

  use CON_coupler, ONLY:nVarIndexCouple, nCoupleVarGroup

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

  integer, public:: nVarCouple
  integer, public:: iVar_V(nVarIndexCouple)
  logical, public:: DoCoupleVar_V(nCoupleVarGroup)

  ! Coupling toolkit
  public:: IH_synchronize_refinement
  public:: IH_get_for_mh
  public:: IH_get_for_mh_with_xyz
  public:: IH_put_from_mh
  public:: IH_n_particle
  type(DomainType), public:: IH_LineDD

  ! Coupling with SC
  public:: IH_set_buffer_grid
  public:: IH_set_buffer_grid_get_info
  public:: IH_save_global_buffer
  public:: IH_match_ibc

  ! Point coupling
  public:: IH_get_grid_info
  public:: IH_find_points

  ! Coupling with SP
  public:: IH_check_ready_for_sp
  public:: IH_get_for_sp
  public:: IH_extract_line
  public:: IH_add_to_line
  public:: IH_get_a_line_point
  public:: IH_get_particle_indexes
  public:: IH_get_particle_coords
  public:: IH_line_interface_point

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
  !==========================================================================
  subroutine IH_set_param(CompInfo, TypeAction)

    use CON_comp_info

    character (len=*), parameter :: NameSub='IH_set_param'

    ! Arguments
    type(CompInfoType), intent(inout):: CompInfo   ! Information for this comp.
    character (len=*), intent(in)    :: TypeAction ! What to do
    !-------------------------------------------------------------------------
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

    !INPUT PARAMETERS:
    integer,  intent(in) :: iSession         ! session number (starting from 1)
    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter :: NameSub='IH_init_session'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_init_session

  !============================================================================

  subroutine IH_finalize(TimeSimulation)

    !INPUT PARAMETERS:
    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter :: NameSub='IH_finalize'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_finalize

  !============================================================================

  subroutine IH_save_restart(TimeSimulation)

    !INPUT PARAMETERS:
    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter :: NameSub='IH_save_restart'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_save_restart

  !============================================================================

  subroutine IH_run(TimeSimulation,TimeSimulationLimit)

    !INPUT/OUTPUT ARGUMENTS:
    real, intent(inout):: TimeSimulation   ! current time of component

    !INPUT ARGUMENTS:
    real, intent(in):: TimeSimulationLimit ! simulation time not to be exceeded

    character(len=*), parameter :: NameSub='IH_run'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_run
  !==============================================================================
  subroutine IH_get_grid_info(nDimOut, iGridOut, iDecompOut)

    integer, intent(out):: nDimOut    ! grid dimensionality
    integer, intent(out):: iGridOut   ! grid index (increases with AMR)
    integer, intent(out):: iDecompOut ! decomposition index 

    character(len=*), parameter :: NameSub='IH_get_grid_info'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_get_grid_info
  !======================================
  subroutine IH_coord_to_xyz(CoordIn_D, XyzOut_D)
    real, intent(in) :: CoordIn_D(3)
    real, intent(out):: XyzOut_D( 3)
    character(len=*), parameter :: NameSub = 'IH_coord_to_xyz'
    !---------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_coord_to_xyz
  !======================================
  subroutine IH_xyz_to_coord(XyzIn_D, CoordOut_D)
    real,             intent(in ) :: XyzIn_D(3)
    real,             intent(out) :: CoordOut_D(3)
    character(len=*), parameter   :: NameSub = 'IH_xyz_to_coord'
    !---------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_xyz_to_coord
  !===============================
  subroutine IH_find_points(nDimIn, nPoint, Xyz_DI, iProc_I)

    integer, intent(in) :: nDimIn                ! dimension of position vectors
    integer, intent(in) :: nPoint                ! number of positions
    real,    intent(in) :: Xyz_DI(nDimIn,nPoint) ! positions
    integer, intent(out):: iProc_I(nPoint)       ! processor owning position

    ! Find array of points and return processor indexes owning them
    ! Could be generalized to return multiple processors...

    character(len=*), parameter:: NameSub = 'IH_find_points'
   
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_find_points
  !===============================================================

  subroutine IH_synchronize_refinement(iProc0,iCommUnion)

    integer, intent(in) ::iProc0,iCommUnion
    character(len=*), parameter :: NameSub='IH_synchronize_refinement'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_synchronize_refinement

  !===============================================================

  subroutine IH_get_for_gm(&
       nPartial,iGetStart,Get,W,State_V,nVar,TimeCoupling)

    use CON_router, ONLY: IndexPtrType, WeightPtrType

    integer,intent(in)::nPartial,iGetStart,nVar
    type(IndexPtrType),intent(in)::Get
    type(WeightPtrType),intent(in)::W
    real,dimension(nVar),intent(out)::State_V
    real,intent(in)::TimeCoupling

    character(len=*), parameter :: NameSub='IH_get_for_gm'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_get_for_gm
  !===================================================================!
  subroutine IH_get_for_mh(&
       nPartial,iGetStart,Get,W,State_V,nVar)

    use CON_router, ONLY: IndexPtrType, WeightPtrType

    integer,intent(in)              ::nPartial,iGetStart,nVar
    type(IndexPtrType),intent(in)   ::Get
    type(WeightPtrType),intent(in)  ::W
    real,dimension(nVar),intent(out)::State_V

    character(len=*), parameter :: NameSub='IH_get_for_mh'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_get_for_mh
  !===================================================================!
  subroutine IH_get_for_mh_with_xyz(&
       nPartial,iGetStart,Get,W,State_V,nVar)

    use CON_router, ONLY: IndexPtrType, WeightPtrType

    integer,intent(in)               :: nPartial,iGetStart,nVar
    type(IndexPtrType),intent(in)    :: Get
    type(WeightPtrType),intent(in)   :: W
    real,dimension(nVar),intent(out) ::State_V

    character(len=*), parameter :: NameSub='IH_get_for_mh_with_xyz'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_get_for_mh_with_xyz
  !===================================================================!
  subroutine IH_set_buffer_grid(DD)

    use CON_router, ONLY: DomainType
    type(DomainType), intent(out)::DD

    character(len=*), parameter :: NameSub='IH_set_buffer_grid'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_set_buffer_grid
  !===================================================================!
  subroutine IH_check_ready_for_sp(IsReady)
    logical, intent(out):: IsReady
    character(len=*), parameter :: NameSub='IH_check_particles'
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_check_ready_for_sp
  !===================================================================!
  subroutine IH_get_for_sp(&
       nPartial,iGetStart,Get,W,State_V,nVar)
    use CON_router, ONLY: IndexPtrType, WeightPtrType

    !INPUT ARGUMENTS:
    integer,intent(in)::nPartial,iGetStart,nVar
    type(IndexPtrType),intent(in)::Get
    type(WeightPtrType),intent(in)::W
    real,dimension(nVar),intent(out)::State_V

    character(len=*), parameter :: NameSub='IH_get_for_sp'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_get_for_sp
  !===================================================================!
  subroutine IH_line_interface_point(&
       Grid,&
       iBlockUsed,    &
       nDim, Xyz_D, nIndex, iIndex_I,&
       IsInterfacePoint)
    use CON_router, ONLY: LocalGridType
    type(LocalGridType),intent(in)::Grid
    integer,intent(in)    :: iBlockUsed,nIndex
    logical,intent(out)   :: IsInterfacePoint
    integer,intent(in)    :: nDim
    real,   intent(inout) :: Xyz_D(nDim)
    integer,intent(inout) :: iIndex_I(nIndex)
    character(len=*), parameter :: NameSub='IH_line_interface_point'
    !----------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_line_interface_point
  !===================================================================!
  subroutine IH_get_particle_indexes(iParticle, iIndex_I)
    integer, intent(in) :: iParticle
    integer, intent(out):: iIndex_I(2)
    character(len=*), parameter:: NameSub='IH_get_particle_indexes'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_get_particle_indexes
  !===================================================================!
  subroutine IH_get_particle_coords(iParticle, Xyz_D)
    integer, intent(in) :: iParticle
    real,    intent(out):: Xyz_D(3)
    character(len=*), parameter:: NameSub='IH_get_particle_coords'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_get_particle_coords
  !===================================================================!
  subroutine IH_extract_line(nLine, XyzOrigin_DI, iTraceMode, &
       nIndex, iIndexOrigin_II, RSoftBoundaryIn, UseInputInGenCoord)
    integer,          intent(in) :: nLine
    real,             intent(in) :: XyzOrigin_DI(3, 1)
    integer,          intent(in) :: iTraceMode
    integer,          intent(in) :: nIndex
    integer,          intent(in) :: iIndexOrigin_II(1,1) 
    real,    optional,intent(in) :: RSoftBoundaryIn
    logical, optional,intent(in) :: UseInputInGenCoord

    character(len=*), parameter :: NameSub='IH_extract_line'
    !----------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_extract_line
  !============================================================================
  subroutine IH_add_to_line(nParticle, Xyz_DI, nIndex, iIndex_II)
    integer, intent(in) :: nParticle
    real,    intent(in) :: Xyz_DI(3, 1)
    integer, intent(in) :: nIndex
    integer, intent(in) :: iIndex_II(1,1)
    character(len=*), parameter :: NameSub='IH_add_to_line'
    !----------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_add_to_line
  !===================================================================!
  subroutine IH_get_a_line_point(&
       nPartial,iGetStart,Get,W,State_V,nVar)

    use CON_router, ONLY: IndexPtrType, WeightPtrType

    integer,intent(in)::nPartial,iGetStart,nVar
    type(IndexPtrType),intent(in)::Get
    type(WeightPtrType),intent(in)::W
    real,dimension(nVar),intent(out)::State_V

    character(len=*), parameter :: NameSub='IH_get_a_line_point'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_get_a_line_point
  !===================================================================!
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

    character (len=*), parameter :: NameSub='IH_put_from_mh.f90'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_put_from_mh
  !===================================================================!
  subroutine IH_match_ibc

    character(len=*), parameter :: NameSub='IH_match_ibc'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_match_ibc
  !===============================================================
  subroutine IH_set_buffer_grid_get_info(CompID_, &
       nR, nPhi, nTheta, BufferMinMax_DI)

    integer, intent(in)     :: CompID_
    integer, intent(out)    :: nR, nPhi, nTheta
    real, intent(out)       :: BufferMinMax_DI(3,2)

    character(len=*), parameter :: NameSub = 'IH_set_buffer_grid_get_info'
    ! ---------------------------------------------------------------

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_set_buffer_grid_get_info
  !===============================================================
  subroutine IH_save_global_buffer(nVar, nR, nPhi, nTheta, BufferIn_VG)

    integer,intent(in) :: nVar, nR, nPhi, nTheta
    real,intent(in)    :: BufferIn_VG(nVar, nR, nPhi, nTheta)

    character(len=*), parameter :: NameSub = 'IH_save_global_buffer'
    !-------------------------------------------------------------

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_save_global_buffer
  !===============================================================
  subroutine IH_get_for_global_buffer(&
       nR, nPhi,nTheta, BufferMinMax_DI, &
       TimeCoupling, iCompSource, iCompTarget, Buffer_VG)

    ! Buffer size and limits
    integer,intent(in) :: nR, nPhi, nTheta
    real, intent(in)   :: TimeCoupling
    real, intent(in)   :: BufferMinMax_DI(3,2)
    integer,intent(in) :: iCompSource, iCompTarget

    ! State variables to be fiiled in all buffer grid points
    real, intent(out):: Buffer_VG(:,:,:,:)

    character (len=*), parameter :: NameSub='IH_get_for_buffer_grid'

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

    character(len=*), parameter :: NameSub='IH_get_for_pt'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_get_for_pt

  !===========================================================================
  subroutine IH_put_from_pt( &
       NameVar, nVar, nPoint, Data_VI, iPoint_I, Pos_DI)

    character(len=*), intent(inout):: NameVar ! List of variables
    integer,          intent(inout):: nVar    ! Number of variables in Data_VI
    integer,          intent(inout):: nPoint  ! Number of points in Pos_DI

    real,    intent(in), optional:: Data_VI(:,:)    ! Recv data array
    integer, intent(in), optional:: iPoint_I(nPoint)! Order of data
    real, intent(out), allocatable, optional:: Pos_DI(:,:) ! Position vectors

    character(len=*), parameter :: NameSub='IH_put_from_pt'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_put_from_pt
  !===========================================================================
  subroutine IH_get_for_pt_dt(DtSi)
    real, intent(out) ::  DtSi
    character(len=*), parameter :: NameSub='IH_get_for_pt_dt'
    !--------------------------------------------------------------------------
    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end subroutine IH_get_for_pt_dt
  !===========================================================================

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

    character(len=*), parameter :: NameSub='IH_get_for_ee'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_get_for_ee

  !===========================================================================
  subroutine IH_put_from_ee( &
       NameVar, nVarData, nPoint, Data_VI, iPoint_I, Pos_DI)

    ! This routine is actually for EE-SC coupling

    character(len=*), intent(inout):: NameVar ! List of variables
    integer,          intent(inout):: nVarData! Number of variables in Data_VI
    integer,          intent(inout):: nPoint  ! Number of points in Pos_DI

    real,    intent(in), optional:: Data_VI(:,:)    ! Recv data array
    integer, intent(in), optional:: iPoint_I(nPoint)! Order of data
    real, intent(out), allocatable, optional:: Pos_DI(:,:) ! Position vectors

    character(len=*), parameter :: NameSub='IH_put_from_ee'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')

  end subroutine IH_put_from_ee
  !============================
  integer function IH_n_particle(iBlockLocal)
    integer, intent(in) :: iBlockLocal
    character(len=*), parameter :: NameSub='IH_n_particle'

    call CON_stop(NameSub//': IH_ERROR: empty version cannot be used!')
  end function IH_n_particle
  
end module IH_wrapper

!==============================================================================

