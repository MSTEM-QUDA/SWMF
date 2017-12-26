!  Copyright (C) 2002 Regents of the University of Michigan, 
!  portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
!==================================================================
module SP_ModReadMhData
  ! This module contains methods for reading input MH data
  use SP_ModSize,    ONLY: nDim, nParticleMax
  use SP_ModGrid,    ONLY: get_node_indexes, nMHData, nVar, nBlock,&
       iShock_IB, iNode_B, FootPoint_VB, nParticle_B, State_VIB,   &
       NameVar_V, LagrID_, X_, Z_, Shock_, ShockOld_, RhoOld_, BOld_
  use SP_ModAdvance, ONLY: TimeGlobal, iIterGlobal, DoTraceShock
  use SP_ModDistribution, ONLY: Distribution_IIB, offset
  use ModPlotFile,   ONLY: read_plot_file
  use ModUtilities,  ONLY: fix_dir_name, open_file, close_file
  use ModIoUnit,     ONLY: io_unit_new
  implicit none
  SAVE
  private ! except
  !\
  !Public members
  public:: init         ! Initialize module variables
  public:: read_param   ! Read module variables
  public:: read_mh_data ! Read MH_data from files
  public:: finalize     ! Finalize module variables DoReadMhData
  ! If the folliwing logical is true, read MH_data from files 
  logical, public :: DoReadMhData = .false.
  !/
  !\
  ! the input directory
  character(len=100)         :: NameInputDir=""
  ! the name with list of file tags
  character(len=100)         :: NameTagFile=""
  ! the input file name base
  character(len=4)           :: NameFileExtension
  character(len=20)          :: TypeMhDataFile

  ! IO unit for file with list of tags
  integer:: iIOTag

contains
  !================================================================
  subroutine read_param(NameCommand)
    use ModReadParam, ONLY: read_var
    ! set parameters of input files with background data
    integer :: nFileRead
    character (len=*), intent(in):: NameCommand ! From PARAM.in  
    character(len=*), parameter :: NameSub='SP:set_read_mh_data_param'
    !--------------------------------------------------------------------------
    select case(NameCommand)
    case('#READMHDATA')
       !
       call read_var('DoReadMhData', DoReadMhData)
       if(.not. DoReadMhData)&
            RETURN
       ! the input directory
       call read_var('NameInputDir', NameInputDir)
       call fix_dir_name(NameInputDir) ! adds "/" if not present
    case('#MHDATA')
       ! type of data files
       call read_var('TypeMhDataFile', TypeMhDataFile)
       ! the format of output file must be set
       select case(trim(TypeMhDataFile))
       case('tec')
          NameFileExtension='.dat'
       case('idl','ascii')
          TypeMhDataFile = 'ascii'
          NameFileExtension='.out'
       case('real4','real8')
          NameFileExtension='.out'
       case default
          call CON_stop(NameSub//': input format was not set in PARAM.in')
       end select
       ! number of input files
       call read_var('nFileRead', nFileRead)
       ! name of the file with the list of tags
       call read_var('NameTagFile', NameTagFile)
    end select
  end subroutine read_param
  !============================================================================
  subroutine init
    ! initialize by setting the time and interation index of input files
    character (len=*), parameter :: NameSub='SP:init_read_mh_data'
    !-------------------------------------------------------------------------
    if(.not.DoReadMhData) RETURN
    ! open the file with the list of tags
    iIOTag = io_unit_new()
    call open_file(iUnitIn=iIOTag, &
         file=trim(NameInputDir)//trim(NameTagFile), status='old')
    ! read the first input file
    call read_mh_data(TimeGlobal, DoOffsetIn = .false.)
  end subroutine init
  !============================================================================
  subroutine finalize
    ! close currentl opend files
    if(DoReadMhData) call close_file(iUnitIn=iIOTag)
  end subroutine finalize
  !============================================================================
  subroutine read_mh_data(TimeOut, DoOffsetIn)
    use SP_ModPlot,    ONLY: NameMHData
    real,              intent(out):: TimeOut
    logical, optional, intent(in ):: DoOffsetIn
    ! read 1D MH data, which are produced by write_mh_1d n ModWrite
    ! separate file is read for each field line, name format is (usually)
    ! MH_data_<iLon>_<iLat>_t<ddhhmmss>_n<iIter>.{out/dat}
    !------------------------------------------------------------------------
    ! name of the input file
    character(len=100):: NameFile
    ! loop variables
    integer:: iBlock
    ! indexes of corresponding node, latitude and longitude
    integer:: iNode, iLat, iLon
    ! number of particles saved in the input file
    integer:: nParticleInput
    ! size of the offset to apply compared to the previous state
    integer:: iOffset
    ! local value of DoOffset
    logical:: DoOffset
    ! auxilary variables to apply positive offset (particles are appended)
    real:: Distance2ToMin, Distance3To2, Alpha
    ! auxilary parameter index
    integer, parameter:: RShock_ = Z_ + 2
    ! additional parameters of lines
    real:: Param_I(LagrID_:RShock_)
    ! timetag
    character(len=50):: StringTag
    character(len=*), parameter:: NameSub = "SP:read_mh_data"
    !------------------------------------------------------------------------
    ! check whether need to apply offset, default is .true.
    if(present(DoOffsetIn))then
       DoOffset = DoOffsetIn
    else
       DoOffset = .true.
    end if
    !\
    ! get the tag for files
    read(iIOTag,'(a)') StringTag
    !/
    ! read the data
    BLOCK:do iBlock = 1, nBlock
       iNode = iNode_B(iBlock)
       call get_node_indexes(iNode, iLon, iLat)
       !\ 
       ! set the file name
       write(NameFile,'(a,i3.3,a,i3.3,a)') &
            trim(NameInputDir)//NameMHData//'_',iLon,&
            '_',iLat, '_'//trim(StringTag)//NameFileExtension
       !/
       ! read the header first
       call read_plot_file(NameFile          ,&
            TypeFileIn = TypeMhDataFile      ,&
            TimeOut    = TimeOut             ,&
            n1out      = nParticle_B(iBlock) ,&
            ParamOut_I = Param_I(LagrID_:RShock_))
       ! find offset in data between new and old states
       if(DoOffset)then
          ! amount of the offset is determined from difference 
          ! in LagrID_ 
          iOffset = FootPoint_VB(LagrID_,iBlock) - Param_I(LagrID_)
       else
          iOffset = 0
       end if
       !Parameters
       FootPoint_VB(LagrID_:Z_,iBlock) = Param_I(LagrID_:Z_)
       !\
       ! read MH data
       call read_plot_file(NameFile          ,&
            TypeFileIn = TypeMhDataFile      ,&
            Coord1Out_I= State_VIB(LagrID_   ,&
            1:nParticle_B(iBlock),iBlock)    ,&
            VarOut_VI  = State_VIB(1:nMHData ,&
            1:nParticle_B(iBlock),iBlock))
       if(iOffset==0) CYCLE BLOCK 
       !\
       ! apply offset
       if(iOffset < 0)then
          call offset(iBlock, iOffset)
       elseif(iOffset > 1)then
          call CON_stop(NameSub//&
               ": invalid offset between consecutive states")
       else !iOffset = 1
          Distance2ToMin = sqrt(sum((State_VIB(X_:Z_,2,iBlock) - &
               FootPoint_VB(X_:Z_,iBlock))**2))
          Distance3To2   = sqrt(sum((State_VIB(X_:Z_,3,iBlock) - &
                State_VIB(X_:Z_,2,iBlock))**2))
          Alpha = Distance2ToMin/(Distance2ToMin + Distance3To2)
          call offset(iBlock, iOffset, Alpha)
       end if
       !/
    end do BLOCK
  end subroutine read_mh_data
end module SP_ModReadMhData
