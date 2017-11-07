!  Copyright (C) 2002 Regents of the University of Michigan, 
!  portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
! Wrapper for the empty Global Magnetosphere (GM) component
!==========================================================================

module GM_wrapper

  use CON_coupler

  implicit none

contains

  subroutine GM_set_param(CompInfo, TypeAction)

    use CON_comp_info

    implicit none

    character (len=*), parameter :: NameSub='GM_set_param'

    ! Arguments
    type(CompInfoType), intent(inout) :: CompInfo   ! Information for this comp.
    character (len=*), intent(in)     :: TypeAction ! What to do
    !-------------------------------------------------------------------------
    select case(TypeAction)
    case('VERSION')
       call put(CompInfo,&
            Use        =.false., &
            NameVersion='Empty', &
            Version    =0.0)

    case default
       call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')
    end select

  end subroutine GM_set_param

  !==============================================================================

  subroutine GM_init_session(iSession, TimeSimulation)

    implicit none

    !INPUT PARAMETERS:
    integer,  intent(in) :: iSession         ! session number (starting from 1)
    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter :: NameSub='GM_init_session'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_init_session

  !==============================================================================

  subroutine GM_finalize(TimeSimulation)

    implicit none

    !INPUT PARAMETERS:
    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter :: NameSub='GM_finalize'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_finalize

  !==============================================================================

  subroutine GM_save_restart(TimeSimulation)

    implicit none

    !INPUT PARAMETERS:
    real,     intent(in) :: TimeSimulation   ! seconds from start time

    character(len=*), parameter :: NameSub='GM_save_restart'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_save_restart

  !==============================================================================

  subroutine GM_run(TimeSimulation,TimeSimulationLimit)

    implicit none

    !INPUT/OUTPUT ARGUMENTS:
    real, intent(inout) :: TimeSimulation   ! current time of component

    !INPUT ARGUMENTS:
    real, intent(in) :: TimeSimulationLimit ! simulation time not to be exceeded

    character(len=*), parameter :: NameSub='GM_run'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_run

  !==============================================================================
  subroutine GM_get_grid_info(nDimOut, iGridOut, iDecompOut)

    implicit none

    integer, intent(out):: nDimOut    ! grid dimensionality
    integer, intent(out):: iGridOut   ! grid index (increases with AMR)
    integer, intent(out):: iDecompOut ! decomposition index

    character(len=*), parameter :: NameSub = 'GM_get_grid_info'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_get_grid_info

  !==============================================================================
  subroutine GM_find_points(nDimIn, nPoint, Xyz_DI, iProc_I)

    implicit none

    integer, intent(in) :: nDimIn                ! dimension of position vectors
    integer, intent(in) :: nPoint                ! number of positions
    real,    intent(in) :: Xyz_DI(nDimIn,nPoint) ! positions
    integer, intent(out):: iProc_I(nPoint)       ! processor owning position

    character(len=*), parameter:: NameSub = 'GM_find_points'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_find_points

  !============================================================================
  subroutine GM_use_pointer(iComp, tSimulation)

    integer, intent(in):: iComp
    real,    intent(in):: tSimulation

    character(len=*), parameter:: NameSub = 'GM_use_pointer'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_use_pointer
  !==============================================================================

  subroutine GM_synchronize_refinement(iProc0,iCommUnion)

    implicit none
    integer,intent(in) :: iProc0,iCommUnion
    character(len=*), parameter :: NameSub='GM_synchronize_refinement'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_synchronize_refinement

  !==============================================================================
  subroutine GM_get_for_im(Buffer_IIV,BufferKp,iSize,jSize,nVar,NameVar)
    implicit none

    integer, intent(in) :: iSize,jSize,nVar
    real, intent(out)   :: BufferKp
    real, intent(out), dimension(iSize,jSize,nVar) :: Buffer_IIV
    character (len=*), intent(in) :: NameVar

    character (len=*), parameter :: NameSub='GM_get_for_im'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')
  end subroutine GM_get_for_im

  !==============================================================================
  subroutine GM_get_for_im_trace(nRadius, nLon, nVarLine, nPointLine, NameVar)

    ! Ray tracing for RAM type codes 
    ! Provides total number of points along rays
    ! and the number of variables to pass to IM

    implicit none
    integer, intent(in)           :: nRadius, nLon
    integer, intent(out)          :: nVarLine, nPointLine
    character (len=*), intent(in) :: NameVar

    character(len=*), parameter :: NameSub = 'GM_get_for_im_trace'
    !---------------------------------------------------------------------
    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_get_for_im_trace
  !==============================================================================

  subroutine GM_get_for_im_line(nRadius, nLon, MapOut_DSII, &
       nVarLine, nPointLine, BufferLine_VI)

    implicit none

    integer, intent(in) :: nRadius, nLon
    real,    intent(out):: MapOut_DSII(3,2,nRadius,nLon)
    integer, intent(in) :: nPointLine, nVarLine
    real, intent(out)   :: BufferLine_VI(nVarLine, nPointLine)

    character (len=*), parameter :: NameSub = 'GM_get_for_im_line'
    !---------------------------------------------------------------------
    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_get_for_im_line

  !==============================================================================

  subroutine GM_put_from_im(Buffer_II,iSizeIn,jSizeIn,nVar,NameVar)
    implicit none

    integer, intent(in) :: iSizeIn,jSizeIn,nVar
    real, intent(in) :: Buffer_II(iSizeIn,jSizeIn)
    character(len=*), intent(in) :: NameVar

    character(len=*), parameter :: NameSub='GM_put_from_im'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')
  end subroutine GM_put_from_im

  !==============================================================================

  subroutine GM_satinit_for_im(nSats)

    implicit none
    character (len=*), parameter :: NameSub='read_pw_buffer'

    integer, intent(out) :: nSats

    call CON_stop(NameSub//'GM_ERROR: empty version cannot be used!')

  end subroutine GM_satinit_for_im

  !==============================================================================

  subroutine GM_get_sat_for_im(Buffer_III, Buffer_I, nSats)

    implicit none

    integer, intent(in)               :: nSats
    real, intent(out)                 :: Buffer_III(3,2,nSats)
    character (len=100), intent(out)  :: Buffer_I(nSats)

  end subroutine GM_get_sat_for_im

  !==============================================================================

  subroutine GM_get_sat_for_im_crcm(Buffer_III, Buffer_I, nSats)

    implicit none

    integer, intent(in)               :: nSats
    real, intent(out)                 :: Buffer_III(4,2,nSats)
    character (len=100), intent(out)  :: Buffer_I(nSats)

  end subroutine GM_get_sat_for_im_crcm

  !==============================================================================
  subroutine GM_get_for_im_trace_crcm(iSizeIn, jSizeIn, NameVar, nVarLine, &
       nPointLine)

    implicit none

    integer, intent(in)           :: iSizeIn, jSizeIn
    character (len=*), intent(in) :: NameVar
    integer, intent(out)          :: nVarLine, nPointLine

    character (len=*), parameter :: NameSub='GM_get_for_im_trace_crcm'

    call CON_stop(NameSub//'GM_ERROR: empty version cannot be used!')  

  end subroutine GM_get_for_im_trace_crcm

  !==============================================================================
  subroutine GM_get_for_im_crcm(Buffer_IIV, KpOut,iSizeIn, jSizeIn, nVarIn, &
       BufferLine_VI, nVarLine, nPointLine, NameVar)

    implicit none

    character (len=*), parameter :: NameSub='GM_get_for_im_crcm'

    integer, intent(in) :: iSizeIn, jSizeIn, nVarIn
    real, intent(out)   :: Buffer_IIV(iSizeIn,jSizeIn,nVarIn), KpOut

    integer, intent(in) :: nPointLine, nVarLine
    real, intent(out)   :: BufferLine_VI(nVarLine, nPointLine)
    character(len=*), intent(in):: NameVar

    call CON_stop(NameSub//'GM_ERROR: empty version cannot be used!')  

  end subroutine GM_get_for_im_crcm

  !==============================================================================

  subroutine GM_get_for_rb_trace(iSize,jSize,NameVar,nVarLine,nPointLine)
    implicit none

    integer, intent(in) :: iSize,jSize
    character (len=*), intent(in) :: NameVar
    integer, intent(out):: nVarLine,nPointLine

    character (len=*), parameter :: NameSub='GM_get_for_rb_trace'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')
  end subroutine GM_get_for_rb_trace

  !==============================================================================

  subroutine GM_get_for_rb(Buffer_IIV,iSize,jSize,nVar, &
       BufferLine_VI, nVarLine, nPointLine, NameVar)

    implicit none

    integer, intent(in) :: iSize,jSize,nVar
    real, intent(out)   :: Buffer_IIV(iSize,jSize,nVar)
    integer, intent(in) :: nVarLine, nPointLine
    real, intent(out)   :: BufferLine_VI(nVarLine, nPointLine)
    character (len=*), intent(in):: NameVar

    character (len=*), parameter :: NameSub='GM_get_for_rb'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')
  end subroutine GM_get_for_rb

  !==============================================================================

  subroutine GM_satinit_for_rb(nSats)
    implicit none
    integer :: nSats
  end subroutine GM_satinit_for_rb

  !==============================================================================

  subroutine GM_get_sat_for_rb(Buffer_III, Buffer_I, nSats)
    implicit none

    integer, intent(in)               :: nSats
    real, intent(out)                 :: Buffer_III(4,2,nSats)
    character (len=100), intent(out)  :: Buffer_I(nSats)
  end subroutine GM_get_sat_for_rb

  !==============================================================================

  subroutine GM_get_for_ie(Buffer_IIV,iSize,jSize,nVar)
    implicit none

    integer, intent(in) :: iSize,jSize,nVar
    real, intent(out), dimension(iSize,jSize,nVar) :: Buffer_IIV

    character (len=*), parameter :: NameSub='GM_get_for_ie'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_get_for_ie

  !============================================================================
  subroutine GM_get_info_for_ie(nVar, NameVar_I)

    integer, intent(out) :: nVar
    character(len=*), intent(out), optional:: NameVar_I(:)

    character(len=*), parameter :: NameSub='GM_get_info_for_ie'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_get_info_for_ie
  !==============================================================================

  subroutine GM_put_from_ie(Buffer_IIV, iSize, jSize, nVar, NameVar_I)

    implicit none

    integer,          intent(in):: iSize, jSize, nVar
    real,             intent(in):: Buffer_IIV(iSize,jSize,nVar)
    character(len=*), intent(in):: NameVar_I(nVar)

    character(len=*), parameter :: NameSub='GM_put_from_ie'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_put_from_ie

  !==============================================================================

  subroutine GM_put_from_ih(nPartial,iPutStart,Put,Weight,DoAdd,StateSI_V,&
       nVar)
    integer,intent(in)::nPartial,iPutStart,nVar
    type(IndexPtrType),intent(in)::Put
    type(WeightPtrType),intent(in)::Weight
    logical,intent(in)::DoAdd
    real,dimension(nVar),intent(in)::StateSI_V

    ! Derived type arguments, it is easier not to declare them
    character(len=*), parameter :: NameSub='GM_put_from_ih'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_put_from_ih

  !==============================================================================

  subroutine GM_put_from_ih_buffer( &
       NameCoord, nY, nZ, yMin, yMax, zMin, zMax, Buffer_VII)

    character(len=*), intent(in) :: NameCoord
    integer,          intent(in) :: nY, nZ
    real,             intent(in) :: yMin, yMax, zMin, zMax
    real,             intent(in) :: Buffer_VII(8, nY, nZ)

    character(len=*), parameter :: NameSub='GM_put_from_ih_buffer'

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_put_from_ih_buffer

  !==============================================================================

  subroutine GM_put_from_pw(Buffer_VI, nVar, nFieldLine, Name_V)

    implicit none
    character (len=*),parameter :: NameSub='GM_put_from_pw'

    integer, intent(in)           :: nVar, nFieldLine
    real, intent(out)             :: Buffer_VI(nVar, nFieldLine)
    character (len=*), intent(in) :: Name_V(nVar)

    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_put_from_pw
  !==============================================================================

  subroutine GM_get_for_pw(nTotalLine,p_I)

    implicit none
    character (len=*),parameter :: NameSub='GM_get_for_pw'

    integer, intent(in)           :: nTotalLine
    real, intent(out)             :: p_I(nTotalLine)


    call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

  end subroutine GM_get_for_pw

  !==============================================================================

  subroutine GM_get_for_pt(IsNew, NameVar, nVarIn, nDimIn, nPoint, Pos_DI, &
       Data_VI)

    implicit none

    logical,          intent(in):: IsNew   ! true for new point array
    character(len=*), intent(in):: NameVar ! List of variables
    integer,          intent(in):: nVarIn  ! Number of variables in Data_VI
    integer,          intent(in):: nDimIn  ! Dimensionality of positions
    integer,          intent(in):: nPoint  ! Number of points in Pos_DI

    real, intent(in) :: Pos_DI(nDimIn,nPoint)  ! Position vectors
    real, intent(out):: Data_VI(nVarIn,nPoint) ! Data array

    character(len=*), parameter :: NameSub='GM_get_for_pt'

    call CON_stop(NameSub//'GM_ERROR: empty version cannot be used!')

  end subroutine GM_get_for_pt

  !==============================================================================

  subroutine GM_get_for_pc_init(nParamInt, nParamReal, iParam_I, Param_I)

    implicit none

    integer, intent(inout) :: nParamInt, nParamReal
    integer, optional, intent(out):: iParam_I(nParamInt)
    real,    optional, intent(out) :: Param_I(nParamReal)

    character(len=*), parameter :: NameSub='GM_get_for_pc_init'
    !--------------------------------------------------------------------------

    call CON_stop(NameSub//'GM_ERROR: empty version cannot be used!')

  end subroutine GM_get_for_pc_init

  !==============================================================================

  subroutine GM_get_for_pc_dt(DtSi)

    implicit none

    real, intent(out) ::  DtSi

    character(len=*), parameter :: NameSub='GM_get_for_pc_dt'
    !--------------------------------------------------------------------------

    call CON_stop(NameSub//'GM_ERROR: empty version cannot be used!')

  end subroutine GM_get_for_pc_dt

  !==============================================================================

  subroutine GM_get_for_pc(IsNew, NameVar, nVarIn, nDimIn, nPoint, Xyz_DI, &
       Data_VI)

    implicit none

    logical,          intent(in):: IsNew   ! true for new point array
    character(len=*), intent(in):: NameVar ! List of variables
    integer,          intent(in):: nVarIn  ! Number of variables in Data_VI
    integer,          intent(in):: nDimIn  ! Dimensionality of positions
    integer,          intent(in):: nPoint  ! Number of points in Xyz_DI

    real, intent(in) :: Xyz_DI(nDimIn,nPoint)  ! Position vectors
    real, intent(out):: Data_VI(nVarIn,nPoint) ! Data array

    character(len=*), parameter :: NameSub='GM_get_for_pc'
    !--------------------------------------------------------------------------

    call CON_stop(NameSub//'GM_ERROR: empty version cannot be used!')

  end subroutine GM_get_for_pc

  !===========================================================================

  subroutine GM_put_from_pc( &
       NameVar, nVar, nPoint, Data_VI, iPoint_I, Pos_DI)

    !  logical,          intent(in)   :: UseData ! true when data is transferred
    ! false if positions are asked
    character(len=*), intent(inout):: NameVar ! List of variables
    integer,          intent(inout):: nVar    ! Number of variables in Data_VI
    integer,          intent(inout):: nPoint  ! Number of points in Pos_DI

    real,    intent(in), optional:: Data_VI(:,:)           ! Recv data array
    integer, intent(in), optional:: iPoint_I(nPoint)       ! Order of data
    real, intent(out), allocatable, optional:: Pos_DI(:,:) ! Position vectors

    character(len=*), parameter :: NameSub='GM_put_from_pc'
    !--------------------------------------------------------------------------

    call CON_stop(NameSub//'GM_ERROR: empty version cannot be used!')

  end subroutine GM_put_from_pc

end module GM_wrapper

!==============================================================================

! This subroutine is only needed because of SC|IH/BATSRUS/src/ModCellBoundary
subroutine read_ih_buffer(y, z, State_V)

  real, intent(in) :: y, z
  real, intent(out):: State_V(8)
  character(len=*), parameter :: NameSub='read_ih_buffer'

  call CON_stop(NameSub//': GM_ERROR: empty version cannot be used!')

end subroutine read_ih_buffer

!==============================================================================

! This subroutine is only needed because of SC|IH/BATSRUS/src/ModFaceBoundary
subroutine read_pw_buffer(FaceCoords_D,nVar,FaceState_V)

  implicit none
  character (len=*),parameter :: NameSub='read_pw_buffer'

  real, intent(in) :: FaceCoords_D(3)
  integer, intent(in) :: nVar
  real, intent(inout) :: FaceState_V(nVar)

  call CON_stop(NameSub//'GM_ERROR: empty version cannot be used!')

end subroutine read_pw_buffer

!=============================================================================

