!^CFG COPYRIGHT UM

module ModRestartFile

  use ModProcMH,     ONLY: iProc, nProc, iComm
  use ModIO,         ONLY: Unit_Tmp, nFile, Dt_Output, Dn_Output, Restart_, &
       restart, save_restart_file, write_prefix, iUnitOut
  use ModMain,       ONLY: GlobalBlk, Global_Block_Number, nI, nJ, nK, Gcn, &
       nBlockAll, nBlock, UnusedBlk, ProcTest, BlkTest, iTest, jTest, kTest, &
       n_step, Time_Simulation, dt_BLK, Cfl, CodeVersion, nByteReal, &
       NameThisComp, iteration_number, DoThinCurrentSheet
  use ModVarIndexes, ONLY: nVar, DefaultState_V, SignB_
  use ModAdvance,    ONLY: State_VGB
  use ModCovariant,  ONLY: NameGridFile
  use ModGeometry,   ONLY: dx_BLK, dy_BLK, dz_BLK, xyzStart_BLK
  use ModParallel,   ONLY: iBlockRestartALL_A
  use ModIO,         ONLY: Restart_Bface                    !^CFG IF CONSTRAINB
  use ModCT,         ONLY: BxFace_BLK,ByFace_BLK,BzFace_BLK !^CFG IF CONSTRAINB
  use ModMain,       ONLY: UseConstrainB                    !^CFG IF CONSTRAINB
  use ModImplicit, ONLY: UseImplicit, &                     !^CFG IF IMPLICIT
       n_prev, ImplOld_VCB, dt_prev                         !^CFG IF IMPLICIT
  use ModKind,       ONLY: Real4_, Real8_
  use ModIoUnit,     ONLY: UnitTmp_
  use ModGmGeoindices, ONLY: DoWriteIndices

  use BATL_lib,      ONLY: write_tree_file, iMortonNode_A, iNode_B

  implicit none

  private ! except

  public read_restart_parameters
  public write_restart_files 
  public read_restart_files
  public init_mod_restart_file
  public string_append_iter

  ! Directories for input and output restart files
  character(len=100), public :: NameRestartInDir ="GM/restartIN/"
  character(len=100), public :: NameRestartOutDir="GM/restartOUT/"

  ! Flags to include iteration number in restart files
  logical, public :: UseRestartInSeries=.false.
  logical, public :: UseRestartOutSeries=.false.

  ! simulation time read in upon restart
  real, public    :: tSimulationRead
    
  ! Local variables
  character(len=*), parameter :: StringRestartExt = ".rst"
  character(len=*), parameter :: NameBlkFile      = "blk"
  character(len=*), parameter :: NameHeaderFile   = "restart.H"
  character(len=*), parameter :: NameDataFile     = "data.rst"
  character(len=*), parameter :: NameIndexFile    = "index.rst"
  character(len=*), parameter :: NameGeoindFile   = "geoindex.txt"

  logical :: RestartBlockLevels=.false. ! Load LEVmin,LEVmax in octree restart
  integer :: nByteRealRead = 8     ! Real precision in restart files

  ! One can use 'block', 'proc' or 'one' format for input and output 
  ! restart files.
  ! The input format is set to 'block' for backwards compatibility
  character (len=20)  :: TypeRestartInFile ='block'

  ! 'proc' should work fine on all machines, so it is the default
  character (len=20)  :: TypeRestartOutFile='proc'

  ! Variables for file and record index for 'proc' type restart files
  integer, allocatable:: iFileMorton_I(:), iRecMorton_I(:)

  character(len=100) :: NameFile

  ! Temporaray variables to read arbitrary precision data files
  real (Real8_) :: Dt8, Time8, Dxyz8_D(3), Xyz8_D(3)
  real (Real4_) :: Dt4, Time4, Dxyz4_D(3), Xyz4_D(3)
  real (Real8_) :: State8_CV(nI,nJ,nK,nVar), State8_VC(nVar,nI,nJ,nK)
  real (Real4_) :: State4_CV(nI,nJ,nK,nVar), State4_VC(nVar,nI,nJ,nK)
  !^CFG IF CONSTRAINB BEGIN
  real (Real8_) :: B8_X(nI+1,nJ,nK), B8_Y(nI,nJ+1,nK), B8_Z(nI,nJ,nK+1)
  real (Real4_) :: B4_X(nI+1,nJ,nK), B4_Y(nI,nJ+1,nK), B4_Z(nI,nJ,nK+1)
  !^CFG END CONSTRAINB

contains

  subroutine init_mod_restart_file

    NameRestartInDir(1:2)  = NameThisComp
    NameRestartOutDir(1:2) = NameThisComp

  end subroutine init_mod_restart_file

  !============================================================================

  subroutine read_restart_parameters(NameCommand)

    use ModReadParam, ONLY: read_var
    use ModUtilities, ONLY: fix_dir_name, check_dir
    use ModMain,      ONLY: UseStrict

    character(len=*), intent(in) :: NameCommand
    integer:: i
    character(len=*), parameter:: NameSub = 'read_restart_parameters'
    !--------------------------------------------------------------------------

    select case(NameCommand)
    case("#SAVERESTART")
       call read_var('DoSaveRestart',save_restart_file)
       if(save_restart_file)then
          if(iProc==0)call check_dir(NameRestartOutDir)
          call read_var('DnSaveRestart',dn_output(restart_))
          call read_var('DtSaveRestart',dt_output(restart_))
          nfile=max(nfile,restart_)
       end if
    case("#NEWRESTART")
       restart=.true.
       call read_var('DoRestartBFace',restart_Bface) !^CFG IF CONSTRAINB
    case("#BLOCKLEVELSRELOADED")
       ! Sets logical for upgrade of restart files 
       ! to include LEVmin and LEVmax
       RestartBlockLevels=.true.
    case("#PRECISION")
       call read_var('nByteReal',nByteRealRead)
       if(nByteReal/=nByteRealRead)then
          if(iProc==0) write(*,'(a,i1,a,i1)') NameSub// &
               ' WARNING: BATSRUS was compiled with ',nByteReal,&
               ' byte reals, requested precision is ',nByteRealRead
          if(UseStrict)call stop_mpi(NameSub// &
               ' ERROR: differing precisions for reals')
       end if
    case("#RESTARTINDIR")
       call read_var("NameRestartInDir",NameRestartInDir)
       call fix_dir_name(NameRestartInDir)
       if (iProc==0) call check_dir(NameRestartInDir)
    case("#RESTARTOUTDIR")
       call read_var("NameRestartOutDir",NameRestartOutDir)
       call fix_dir_name(NameRestartOutDir)
       if (iProc==0) call check_dir(NameRestartOutDir)
    case("#RESTARTINFILE")
       call read_var('TypeRestartInFile',TypeRestartInFile)
       i = index(TypeRestartInFile, 'series')
       UseRestartInSeries = i > 0
       if(i > 0) TypeRestartInFile = TypeRestartInFile(1:i-1)

    case("#RESTARTOUTFILE")
       call read_var('TypeRestartOutFile',TypeRestartOutFile)
       i = index(TypeRestartOutFile, 'series')
       UseRestartOutSeries = i > 0
       if(i > 0) TypeRestartOutFile = TypeRestartOutFile(1:i-1)

    case default
       call stop_mpi(NameSub//' unknown NameCommand='//NameCommand)
    end select

  end subroutine read_restart_parameters

  !============================================================================

  subroutine write_restart_files

    integer :: iBlock
    character(len=*), parameter :: NameSub='write_restart_files'
    !------------------------------------------------------------------------
    call timing_start(NameSub)

    if(SignB_>1 .and. DoThinCurrentSheet)then
       do iBlock = 1, nBlock
          if (.not.unusedBLK(iBlock)) call reverse_field(iBlock)
       end do
    end if

    write(NameFile,'(a)') trim(NameRestartOutDir)//'octree.rst'
    if (UseRestartOutSeries) &
         call string_append_iter(NameFile,iteration_number)
    call write_tree_file(NameFile)

    if(iProc==0) call write_restart_header
    select case(TypeRestartOutFile)
    case('block')
       do iBlock = 1, nBlock
          if (.not.unusedBLK(iBlock)) call write_restart_file(iBlock)
       end do
    case('proc')
       allocate(iFileMorton_I(nBlockAll), iRecMorton_I(nBlockAll))
       iFileMorton_I = 0
       iRecMorton_I  = 0
       call write_direct_restart_file
       call write_restart_index
       deallocate(iFileMorton_I, iRecMorton_I)
    case('one')
       call write_direct_restart_file
    case default
       call stop_mpi('Unknown TypeRestartOutFile='//TypeRestartOutFile)
    end select
    if(iProc==0)call save_advected_points
    if(DoWriteIndices .and. iProc==0)call write_geoind_restart

    if(SignB_>1 .and. DoThinCurrentSheet)then
       do iBlock = 1, nBlock
          if (.not.unusedBLK(iBlock)) call reverse_field(iBlock)
       end do
    end if

    call timing_stop(NameSub)

  end subroutine write_restart_files

  !===========================================================================

  subroutine read_restart_files

    integer :: iBlock
    character(len=*), parameter :: NameSub='read_restart_files'
    !------------------------------------------------------------------------
    call timing_start(NameSub)
    select case(TypeRestartInFile)
    case('block')
       do iBlock = 1, nBlock
          if (.not.unusedBLK(iBlock)) call read_restart_file(iBlock)
       end do
    case('proc')
       allocate(iFileMorton_I(nBlockAll), iRecMorton_I(nBlockAll))
       call read_restart_index
       call read_direct_restart_file
       deallocate(iFileMorton_I, iRecMorton_I)
    case('one')
       call read_direct_restart_file
    case default
       call stop_mpi('Unknown TypeRestartInFile='//TypeRestartinFile)
    end select

    do iBlock = 1, nBlock
       if (.not.unusedBLK(iBlock)) call fix_block_geometry(iBlock)
    end do

    if(SignB_>1 .and. DoThinCurrentSheet)then
       do iBlock = 1, nBlock
          if (.not.unusedBLK(iBlock)) call reverse_field(iBlock)
       end do
    end if

    ! Try reading geoIndices restart file if needed
    if(DoWriteIndices .and. iProc==0)call read_geoind_restart

    call timing_stop(NameSub)

  end subroutine read_restart_files

  !===========================================================================

  subroutine write_restart_header

    use ModMain,       ONLY: Dt, NameThisComp, TypeCoordSystem,&
         nBlockAll, Body1, Time_Accurate, iStartTime_I, IsStandAlone
    use ModMain,       ONLY: UseBody2,UseOrbit            !^CFG IF SECONDBODY
    use ModVarIndexes, ONLY: NameEquation, nVar, nFluid
    use ModGeometry, ONLY: x1, x2, y1, y2, z1, z2
    use ModGeometry, ONLY: XyzMin_D, XyzMax_D, &             
         TypeGeometry, UseCovariant, UseVertexBasedGrid      
    use ModParallel, ONLY: proc_dims
    use ModUser,     ONLY: NameUserModule, VersionUserModule
    use ModPhysics
    use CON_planet,  ONLY: NamePlanet
    use ModReadParam,ONLY: i_line_command
    use ModIO,       ONLY: NameMaxTimeUnit

    integer :: iFluid
    !--------------------------------------------------------------------------

    if (iProc/=0) RETURN

    NameFile = trim(NameRestartOutDir)//NameHeaderFile
    if (UseRestartOutSeries) call string_append_iter(NameFile,iteration_number)
    
    open(unit_tmp,file=NameFile)

    write(unit_tmp,'(a)')'#CODEVERSION'
    write(unit_tmp,'(f5.2,a35)')CodeVersion,'CodeVersion'
    write(unit_tmp,*)
    write(unit_tmp,'(a)')'#USERMODULE'
    write(unit_tmp,'(a)')       NameUserModule
    write(unit_tmp,'(f5.2,a35)')VersionUserModule,'VersionUserModule'
    write(unit_tmp,*)
    write(unit_tmp,'(a)')'#COMPONENT'
    write(unit_tmp,'(a2,a38)')NameThisComp,'NameComp'
    write(unit_tmp,*)
    write(unit_tmp,'(a)')'#PRECISION'
    write(unit_tmp,'(i1,a39)')nByteReal,'nByteReal'
    write(unit_tmp,*)
    write(unit_tmp,'(a)')'#EQUATION'
    write(unit_tmp,'(a,a32)')NameEquation,'NameEquation'
    write(unit_tmp,'(i8,a32)')nVar,'nVar'
    write(unit_tmp,*)
    write(unit_tmp,'(a)')'#CHECKGRIDSIZE'
    write(unit_tmp,'(i8,a32)') nI,'nI'
    write(unit_tmp,'(i8,a32)') nJ,'nJ'
    write(unit_tmp,'(i8,a32)') nK,'nK'
    write(unit_tmp,'(i8,a32)') nBlockALL,'MinBlockALL'
    if (IsStandAlone .and. NameThisComp == 'GM') then
       write(unit_tmp,*)
       write(unit_tmp,'(a)')'#PLANET'
       write(unit_tmp,'(a,a32)') NamePlanet,'NamePlanet'
       if(i_line_command("#IDEALAXES", iSessionIn=1) > 0)then
          write(unit_tmp,*)
          write(unit_tmp,'(a)')'#IDEALAXES'
       end if
    end if
    write(unit_tmp,*)
    write(unit_tmp,'(a)')'#NEWRESTART'
    write(unit_tmp,'(l1,a39)')UseConstrainB,'DoRestartBFace'!^CFG IF CONSTRAINB
    write(unit_tmp,*)
    write(unit_tmp,'(a)')'#RESTARTINFILE'
    ! Note that the output file format is saved as the input for next restart
    write(unit_tmp,'(a,a30)')TypeRestartOutFile,'TypeRestartInFile'
    write(unit_tmp,*)
    write(unit_tmp,'(a)')'#BLOCKLEVELSRELOADED'
    write(unit_tmp,*)
    write(unit_tmp,'(a)')'#NSTEP'
    write(unit_tmp,'(i8,a32)')n_step,'nStep'
    write(unit_tmp,*)
    if(n_prev == n_step)then                            !^CFG IF IMPLICIT BEGIN
       write(unit_tmp,'(a)')'#NPREVIOUS'
       write(unit_tmp,'(i8,a32)')n_prev,'nPrev'
       write(unit_tmp,'(es22.15,a18)')dt_prev,'DtPrev'
       write(unit_tmp,*)
    end if                                              !^CFG END IMPLICIT
    write(unit_tmp,'(a)')'#STARTTIME'
    write(unit_tmp,'(i8,a32)')iStartTime_I(1),'iYear'
    write(unit_tmp,'(i8,a32)')iStartTime_I(2),'iMonth'
    write(unit_tmp,'(i8,a32)')iStartTime_I(3),'iDay'
    write(unit_tmp,'(i8,a32)')iStartTime_I(4),'iHour'
    write(unit_tmp,'(i8,a32)')iStartTime_I(5),'iMinute'
    write(unit_tmp,'(i8,a32)')iStartTime_I(6),'iSecond'
    write(unit_tmp,*)
    write(unit_tmp,'(a)')'#TIMESIMULATION'
    write(unit_tmp,'(es22.15,a18)')time_simulation,'tSimulation'
    write(unit_tmp,*)
    if(UseCovariant)then                        
       write(unit_tmp,'(a)')'#GRIDGEOMETRY'
       write(unit_tmp,'(a20,a20)')TypeGeometry,'TypeGeometry'
       if(TypeGeometry == 'spherical_genr') &
         write(unit_tmp,'(a20,a20)')NameGridFile,'NameGridFile' 
       write(unit_tmp,*)
       write(unit_tmp,'(a)')'#VERTEXBASEDGRID'
       write(unit_tmp,'(l1,a39)') UseVertexBasedGrid,'UseVertexBasedGrid'
       write(unit_tmp,*)
    end if
    write(unit_tmp,'(a)')'#GRID'
    write(unit_tmp,'(i8,a32)')proc_dims(1),'nRootBlockX'
    write(unit_tmp,'(i8,a32)')proc_dims(2),'nRootBlockY'
    write(unit_tmp,'(i8,a32)')proc_dims(3),'nRootBlockZ'
    write(unit_tmp,'(es22.15,a18)')x1,'xMin'
    write(unit_tmp,'(es22.15,a18)')x2,'xMax'
    write(unit_tmp,'(es22.15,a18)')y1,'yMin'
    write(unit_tmp,'(es22.15,a18)')y2,'yMax'
    write(unit_tmp,'(es22.15,a18)')z1,'zMin'
    write(unit_tmp,'(es22.15,a18)')z2,'zMax'
    write(unit_tmp,*)
    if(UseCovariant)then                        
       write(unit_tmp,'(a)')'#LIMITGENCOORD1'                   
       write(unit_tmp,'(es22.15,a18)')XyzMin_D(1),'XyzMin_D(1)' 
       write(unit_tmp,'(es22.15,a18)')XyzMax_D(1),'XyzMax_D(1)' 
       write(unit_tmp,*)
    end if                                      
    write(unit_tmp,'(a)')'#COORDSYSTEM'
    write(unit_tmp,'(a3,a37)') TypeCoordSystem,'TypeCoordSystem'
    write(unit_tmp,*)
    write(unit_tmp,'(a)')'#SOLARWIND'
    write(unit_tmp,'(es22.15,a18)')SW_n_dim,  'SwNDim'
    write(unit_tmp,'(es22.15,a18)')SW_T_dim,  'SwTDim'
    write(unit_tmp,'(es22.15,a18)')SW_Ux_dim, 'SwUxDim'
    write(unit_tmp,'(es22.15,a18)')SW_Uy_dim, 'SwUyDim'
    write(unit_tmp,'(es22.15,a18)')SW_Uz_dim, 'SwUzDim'
    write(unit_tmp,'(es22.15,a18)')SW_Bx_dim, 'SwBxDdim'
    write(unit_tmp,'(es22.15,a18)')SW_By_dim, 'SwByDim'
    write(unit_tmp,'(es22.15,a18)')SW_Bz_dim, 'SwBzDim'
    write(unit_tmp,*)
    write(unit_tmp,'(a)')'#IOUNITS'
    write(unit_tmp,'(a20,a20)')TypeIoUnit,'TypeIoUnit'
    write(unit_tmp,*)
    write(unit_tmp,'(a)')'#NORMALIZATION'
    write(unit_tmp,'(a)')'READ'
    write(unit_tmp,'(es22.15,a18)')No2Si_V(UnitX_),   'No2SiUnitX'
    write(unit_tmp,'(es22.15,a18)')No2Si_V(UnitU_),   'No2SiUnitU'
    write(unit_tmp,'(es22.15,a18)')No2Si_V(UnitRho_), 'No2SiUnitRho'
    write(unit_tmp,*)
    write(unit_tmp,'(a)')'#PLOTFILENAME'
    write(unit_tmp,'(a10,a30)') NameMaxTimeUnit, 'NameMaxTimeUnit'
    write(unit_tmp,*)

    if(body1)then
       write(unit_tmp,'(a)')'#BODY'
       write(unit_tmp,'(l1,a39)')      .true., 'UseBody'
       write(unit_tmp,'(es22.15,a18)') rBody, 'rBody'
       if(NameThisComp=='GM') &
            write(unit_tmp,'(es22.15,a18)') rCurrents, 'rCurrents'
       do iFluid = IonFirst_, nFluid
          write(unit_tmp,'(es22.15,a18)') BodyNDim_I(iFluid), 'BodyNDim'
          write(unit_tmp,'(es22.15,a18)') BodyTDim_I(iFluid), 'BodyTDim'
       end do
       write(unit_tmp,*)
    end if
    !^CFG IF SECONDBODY BEGIN
    if(UseBody2)then
       write(unit_tmp,'(a)')'#SECONDBODY'
       write(unit_tmp,'(l1,a39)')     UseBody2,      'UseBody2'
       write(unit_tmp,'(es22.15,a18)')Rbody2,        'rBody2'
       write(unit_tmp,'(es22.15,a18)')xbody2,        'xBody2'
       write(unit_tmp,'(es22.15,a18)')ybody2,        'yBody2'
       write(unit_tmp,'(es22.15,a18)')zbody2,        'zBody2'
       write(unit_tmp,'(es22.15,a18)')rCurrentsBody2,'rCurrentsBody2'
       write(unit_tmp,'(es22.15,a18)')RhoDimBody2,   'RhoDimBody2'
       write(unit_tmp,'(es22.15,a18)')tDimBody2,     'tDimBody2'
       write(unit_tmp,'(l1,a39)')     UseOrbit,      'UseOrbit'
       write(unit_tmp,'(es22.15,a18)')OrbitPeriod,   'OrbitPeriod'
       write(unit_tmp,*)
    end if
    !^CFG END SECONDBODY
    write(unit_tmp,'(a)')'#END'
    write(unit_tmp,*)
    write(unit_tmp,'(a)')'Additional info'
    write(unit_tmp,*)
    write(unit_tmp,'(l8,a)') time_accurate,   ' time_accurate'
    write(unit_tmp,*)
    if(time_accurate)write(unit_tmp,'(2es13.5,a)')&
         time_simulation, dt, ' time_simulation, dt'

    write(unit_tmp,'(a)')'Io2Si_V='
    write(unit_tmp,'(100es13.5)') Io2Si_V
    write(unit_tmp,'(a)')'No2Io_V='
    write(unit_tmp,'(100es13.5)') No2Io_V

    close(unit_tmp)

  end subroutine write_restart_header

  !===========================================================================
  subroutine write_restart_index

    use ModMpi, ONLY: MPI_reduce, MPI_INTEGER, MPI_SUM

    integer, allocatable:: Int_I(:)
    integer:: iMorton, iError
    !-------------------------------------------------------------------------
    if(nProc > 1)then
       ! Collect file and record indexes onto the root processor
       allocate(Int_I(nBlockAll))
       call MPI_reduce(iFileMorton_I, Int_I, nBlockAll, MPI_INTEGER, &
            MPI_SUM, 0, iComm, iError)
       iFileMorton_I = Int_I
       call MPI_reduce(iRecMorton_I, Int_I, nBlockAll, MPI_INTEGER, &
            MPI_SUM, 0, iComm, iError)
       iRecMorton_I = Int_I
       deallocate(Int_I)
    end if

    if(iProc /= 0) RETURN

    ! Save index file
    NameFile = trim(NameRestartOutDir)//NameIndexFile
    if (UseRestartOutSeries) call string_append_iter(NameFile,iteration_number)
    open(UnitTmp_, FILE=NameFile, STATUS='replace')
    write(UnitTmp_,*) nBlockAll
    do iMorton = 1, nBlockAll
       write(UnitTmp_,*) iFileMorton_I(iMorton), iRecMorton_I(iMorton)
    end do
    close(UnitTmp_)
    
  end subroutine write_restart_index
  !===========================================================================
  subroutine read_restart_index

    integer:: iMorton, nBlockAllRead
    !-------------------------------------------------------------------------
    NameFile = trim(NameRestartInDir)//NameIndexFile
    if (UseRestartInSeries) call string_append_iter(NameFile,iteration_number)
    open(UnitTmp_, FILE=NameFile, STATUS='old')
    read(UnitTmp_,*) nBlockAllRead

    if(nBlockAllRead /= nBlockAll) &
         call stop_mpi('Incorrect nBlockAll value in //trim(NameFile)')

    do iMorton = 1, nBlockAll
       read(UnitTmp_,*) iFileMorton_I(iMorton), iRecMorton_I(iMorton)
    end do
    close(UnitTmp_)

  end subroutine read_restart_index
  !============================================================================
  subroutine read_restart_file(iBlock)

    use ModEnergy, ONLY: calc_energy_cell

    integer, intent(in) :: iBlock

    integer   :: iVar, i, j, k, iError, iBlockRestart
    character :: StringDigit

    character (len=*), parameter :: NameSub='read_restart_file'
    logical :: DoTest, DoTestMe
    !--------------------------------------------------------------------
    if(iProc==PROCtest.and.iBlock==BLKtest)then
       call set_oktest(NameSub, DoTest, DoTestMe)
    else
       DoTest=.false.; DoTestMe=.false.
    end if
    
    iBlockRestart = iMortonNode_A(iNode_B(iBlock))

    write(StringDigit,'(i1)') max(5,1+int(alog10(real(iBlockRestart))))

    write(NameFile,'(a,i'//StringDigit//'.'//StringDigit//',a)') &
         trim(NameRestartInDir)//NameBlkFile,iBlockRestart,StringRestartExt
    if (UseRestartInSeries) call string_append_iter(NameFile,iteration_number)

    open(unit_tmp, file=NameFile, status='old', form='UNFORMATTED',&
         iostat = iError)

    if(iError /= 0) call stop_mpi(NameSub// &
         ' read_restart_file could not open: '//trim(NameFile))

    ! Fill in ghost cells
    do k=-1,nK+2; do j=-1,nJ+2; do i=-1,nI+2
       State_VGB(1:nVar, i, j, k, iBlock) = DefaultState_V(1:nVar)
    end do;end do;end do

    ! Do not overwrite time_simulation which is read from header file
    if(nByteRealRead == 8)then
       read(unit_tmp, iostat = iError) Dt8, Time8
       dt_BLK(iBlock) = Dt8
       tSimulationRead   = Time8

       read(unit_tmp, iostat = iError) Dxyz8_D, Xyz8_D
       Dx_BLK(iBlock) = Dxyz8_D(1)
       Dy_BLK(iBlock) = Dxyz8_D(2)
       Dz_BLK(iBlock) = Dxyz8_D(3)
       XyzStart_BLK(:,iBlock) = Xyz8_D

       read(Unit_tmp, iostat = iError) State8_CV
       do iVar = 1, nVar
          State_VGB(iVar,1:nI,1:nJ,1:nK,iBlock) = State8_CV(:,:,:,iVar)
       end do

       if(Restart_Bface)then                          !^CFG IF CONSTRAINB BEGIN
          read(Unit_tmp, iostat = iError) b8_X, b8_Y, b8_Z               
          BxFace_BLK(1:nI+1,1:nJ,1:nK,iBlock) = b8_X
          ByFace_BLK(1:nI,1:nJ+1,1:nK,iBlock) = b8_Y
          BzFace_BLK(1:nI,1:nJ,1:nK+1,iBlock) = b8_Z
       end if                                         !^CFG END CONSTRAINB
       if(n_prev==n_step) then                        !^CFG IF IMPLICIT BEGIN
          read(Unit_tmp, iostat = iError) State8_CV
          do iVar = 1, nVar
             ImplOld_VCB(iVar,:,:,:,iBlock) = State8_CV(:,:,:,iVar)
          end do
       end if                                         !^CFG END IMPLICIT
    else
       read(unit_tmp, iostat = iError) Dt4, Time4
       dt_BLK(iBlock) = Dt4
       tSimulationRead   = Time4

       read(unit_tmp, iostat = iError) Dxyz4_D, Xyz4_D
       Dx_BLK(iBlock) = Dxyz4_D(1)
       Dy_BLK(iBlock) = Dxyz4_D(2)
       Dz_BLK(iBlock) = Dxyz4_D(3)
       XyzStart_BLK(:,iBlock) = Xyz4_D

       read(Unit_tmp, iostat = iError) State4_CV
       do iVar = 1, nVar
          State_VGB(iVar,1:nI,1:nJ,1:nK,iBlock) = State4_CV(:,:,:,iVar)
       end do

       if(Restart_Bface)then                          !^CFG IF CONSTRAINB BEGIN
          read(Unit_tmp, iostat = iError) b4_X, b4_Y, b4_Z               
          BxFace_BLK(1:nI+1,1:nJ,1:nK,iBlock) = b4_X
          ByFace_BLK(1:nI,1:nJ+1,1:nK,iBlock) = b4_Y
          BzFace_BLK(1:nI,1:nJ,1:nK+1,iBlock) = b4_Z
       end if                                         !^CFG END CONSTRAINB
       if(n_prev==n_step) then                        !^CFG IF IMPLICIT BEGIN
          read(Unit_tmp, iostat = iError) State4_CV
          do iVar = 1, nVar
             ImplOld_VCB(iVar,:,:,:,iBlock) = State4_CV(:,:,:,iVar)
          end do
       end if                                         !^CFG END IMPLICIT
    endif

    if(iError /= 0) call stop_mpi(NameSub// &
         ' could not read data from '//trim(NameFile))

    close(unit_tmp)

    if(CodeVersion>5.60 .and. CodeVersion <7.00) &
         dt_BLK(iBlock)=dt_BLK(iBlock)/cfl

    call calc_energy_cell(iBlock)

    if(Dx_BLK(iBlock) < 0 .or. Dy_BLK(iBlock) < 0 .or. Dz_BLK(iBlock) < 0 &
         .or. Dt_BLK(iBlock) < 0 .or. tSimulationRead < 0)then
       write(*,*)NameSub,': corrupt restart data!!!'
       write(*,*)'iBlock  =', iBlock
       write(*,*)'Dxyz    =', Dx_BLK(iBlock), Dy_BLK(iBlock), Dz_BLK(iBlock)
       write(*,*)'Dt,tSim =', Dt_BLK(iBlock), tSimulationRead
       write(*,*)'XyzStart=', XyzStart_BLK(:,iBlock)
       write(*,*)'State111=', State_VGB(1:nVar,1,1,1,iBlock)
       call stop_mpi(NameSub//': corrupt restart data!!!')
    end if

    if(DoTestMe)then
       write(*,*)NameSub,': iProc, iBlock =',iProc, iBlock
       write(*,*)NameSub,': dt,tSimRead =',dt_BLK(iBlock),tSimulationRead
       write(*,*)NameSub,': dx,dy,dz_BLK=',&
            dx_BLK(iBlock),dy_BLK(iBlock),dz_BLK(iBlock)
       write(*,*)NameSub,': xyzStart_BLK=',xyzStart_BLK(:,iBlock)
       write(*,*)NameSub,': State_VGB   =', &
            State_VGB(:,Itest,Jtest,Ktest,iBlock)
       write(*,*)NameSub,' finished'
    end if

  end subroutine read_restart_file

  !===========================================================================

  subroutine write_restart_file(iBlock)

    integer, intent(in) :: iBlock

    character (len=*), parameter :: NameSub='write_restart_file'
    integer:: iVar, iBlockRestart
    character:: StringDigit
    !--------------------------------------------------------------------

    iBlockRestart = iMortonNode_A(iNode_B(iBlock))

    write(StringDigit,'(i1)') max(5,int(1+alog10(real(iBlockRestart))))

    write(NameFile,'(a,i'//StringDigit//'.'//StringDigit//',a)') &
         trim(NameRestartOutDir)//NameBlkFile,iBlockRestart,StringRestartExt

    if (UseRestartOutSeries) call string_append_iter(NameFile,iteration_number)

    open(unit_tmp, file=NameFile, status="replace", form='UNFORMATTED')

    write(Unit_tmp)  dt_BLK(iBlock),time_Simulation
    write(Unit_tmp) &
         dx_BLK(iBlock),dy_BLK(iBlock),dz_BLK(iBlock),&
         xyzStart_BLK(:,iBlock)
    write(Unit_tmp) &
         ( State_VGB(iVar,1:nI,1:nJ,1:nK,iBlock), iVar=1,nVar)
    if(UseConstrainB)then                            !^CFG iF CONSTRAINB BEGIN
       write(Unit_tmp) &
            BxFace_BLK(1:nI+1,1:nJ,1:nK,iBlock),&
            ByFace_BLK(1:nI,1:nJ+1,1:nK,iBlock),&
            BzFace_BLK(1:nI,1:nJ,1:nK+1,iBlock)
    end if                                           !^CFG END CONSTRAINB
    if(n_prev==n_step) write(Unit_tmp) &                !^CFG IF IMPLICIT
         (ImplOld_VCB(iVar,:,:,:,iBlock), iVar=1,nVar)  !^CFG IF IMPLICIT
    close(unit_tmp)

  end subroutine write_restart_file

  !============================================================================

  subroutine open_direct_restart_file(DoRead, iFile)

    logical, intent(in)           :: DoRead
    integer, intent(in), optional :: iFile 

    integer :: lRecord, l, lReal, iError
    character(len=*), parameter :: NameSub='open_direct_restart_file'
    logical :: DoTest, DoTestme
    !-------------------------------------------------------------------------

    call set_oktest(NameSub, DoTest, DoTestMe)
    if(DoTestMe)write(*,*) NameSub,' starting with DoRead=',DoRead

    ! Size of a single real number in units of record length
    inquire (IOLENGTH = lReal) 1.0

    ! Calculate the record length for the first block
    inquire (IOLENGTH = lRecord ) &
         Dt_BLK(1), Dx_BLK(1), Dy_BLK(1), Dz_BLK(1),&
         XyzStart_BLK(:,1), &
         State_VGB(1:nVar,1:nI,1:nJ,1:nK,1)

    if(DoRead .and. Restart_Bface .or. &         !^CFG iF CONSTRAINB BEGIN
         .not.DoRead .and. UseConstrainB)then
       l = lReal*((nI+1)*nJ*nK + nI*(nJ+1)*nK + nI*nJ*(nK+1))
       lRecord = lRecord + l
    end if                                       !^CFG END CONSTRAINB
    if(n_prev==n_step)then                       !^CFG IF IMPLICIT BEGIN
       l = lReal*nVar*nI*nJ*nK
       lRecord = lRecord + l
    end if                                       !^CFG END IMPLICIT

    if(DoTestMe)write(*,*) NameSub,' nByteReal, nByteRealRead, lRecord=',&
          nByteReal, nByteRealRead, lRecord   

    if(DoRead)then
       if(nByteReal /= nByteRealRead) &
            lRecord = (lRecord * nByteRealRead)/nByteReal

       NameFile = trim(NameRestartInDir)//NameDataFile
       if (present(iFile)) &
            write(NameFile, '(a,i6.6)') trim(NameFile)//'_p', iFile
       if (UseRestartInSeries) &
            call string_append_iter(NameFile, iteration_number)

       open(Unit_Tmp, file=NameFile, &
            RECL = lRecord, ACCESS = 'direct', FORM = 'unformatted', &
            status = 'old', iostat=iError)
    else
       NameFile = trim(NameRestartOutDir)//NameDataFile
       if (present(iFile)) &
            write(NameFile, '(a,i6.6)') trim(NameFile)//'_p', iFile
       if (UseRestartOutSeries) &
            call string_append_iter(NameFile,iteration_number)

       ! Delete and open file (only from proc 0 for type 'one')
       if(iProc==0 .or. TypeRestartOutFile == 'proc') &
            open(Unit_Tmp, file=NameFile, &
            RECL = lRecord, ACCESS = 'direct', FORM = 'unformatted', &
            status = 'replace', iostat=iError)

       if(TypeRestartOutFile == 'one') then
          ! Make sure that all processors wait until the file is re-opened
          call barrier_mpi
          if(iProc > 0)open(Unit_Tmp, file=NameFile, &
               RECL = lRecord, ACCESS = 'direct', FORM = 'unformatted', &
               status = 'old', iostat=iError)
       end if
    end if
    if(iError /= 0)then
       write(*,*) NameSub,': ERROR for DoRead=',DoRead
       call stop_mpi(NameSub//': could not open file='//NameFile)
    end if

  end subroutine open_direct_restart_file

  !============================================================================

  subroutine read_direct_restart_file

    character (len=*), parameter :: NameSub='read_direct_restart_file'
    integer :: i, j, k, iBlock, iMorton, iRec, iVar, iFile, iFileLast = -1
    logical :: IsRead, DoTest, DoTestMe
    !-------------------------------------------------------------------------

    call set_oktest(NameSub, DoTest, DoTestMe)

    if(TypeRestartInFile == 'one') &
         call open_direct_restart_file(DoRead = .true.)

    if(DoTestMe)write(*,*) NameSub,' starting with nBlock=', nBlock

    do iBlock = 1, nBlock

       if(UnusedBlk(iBlock)) CYCLE
       ! Use the global block index as the record number
       iMorton = iMortonNode_A(iNode_B(iBlock))

       if(TypeRestartInFile == 'proc')then
          ! Find the appropriate 'proc' restart file and the record number
          iFile = iFileMorton_I(iMorton)
          iRec  = iRecMorton_I(iMorton)          
          if(iFile /= iFileLast) then
             if(iFileLast > 0) close(UnitTmp_)
             call open_direct_restart_file(DoRead = .true., iFile = iFile)
             iFileLast = iFile
          end if
       else
          ! For 'one' restart file record index is given by Morton index
          iRec = iMorton
       end if

       if(DoTestMe) write(*,*) NameSub,' iBlock, iRec=', iBlock, iRec

       ! Fill in ghost cells
       do k=-1,nK+2; do j=-1,nJ+2; do i=-1,nI+2
          State_VGB(1:nVar, i, j, k, iBlock) = DefaultState_V(1:nVar)
       end do; end do; end do

       IsRead = .false.
       if(nByteRealRead == 4)then
          if(Restart_Bface)then                       !^CFG IF CONSTRAINB BEGIN
             ! Read with face centered magnetic field for constrained transport
             read(Unit_Tmp, rec=iRec) Dt4, Dxyz4_D, Xyz4_D, State4_VC, &
                  B4_X, B4_Y, B4_Z
             if(UseConstrainB)then
                BxFace_BLK(1:nI+1,1:nJ,1:nK,iBlock) = B4_X
                ByFace_BLK(1:nI,1:nJ+1,1:nK,iBlock) = B4_Y
                BzFace_BLK(1:nI,1:nJ,1:nK+1,iBlock) = B4_Z
             end if
             IsRead = .true.
          endif                                       !^CFG END CONSTRAINB
          if(n_prev==n_step)then                      !^CFG IF IMPLICIT BEGIN
             ! Read with previous state for sake of implicit BDF2 scheme
             read(Unit_Tmp, rec=iRec) Dt4, Dxyz4_D, Xyz4_D, State4_VC, &
                  State4_CV
             if(UseImplicit)then
                do iVar = 1, nVar
                   ImplOld_VCB(iVar,:,:,:,iBlock) = State4_CV(:,:,:,iVar)
                end do
             end if
             IsRead = .true.
          end if                                       !^CFG END IMPLICIT
          if(.not.IsRead) &
               read(Unit_Tmp, rec=iRec) Dt4, Dxyz4_D, Xyz4_D, State4_VC
          
          Dt_BLK(iBlock) = Dt4
          Dx_BLK(iBlock) = Dxyz4_D(1)
          Dy_BLK(iBlock) = Dxyz4_D(2)
          Dz_BLK(iBlock) = Dxyz4_D(3)
          XyzStart_BLK(:,iBlock) = Xyz4_D
          State_VGB(1:nVar,1:nI,1:nJ,1:nK,iBlock) = State4_VC

       else
          if(Restart_Bface)then                       !^CFG IF CONSTRAINB BEGIN
             ! Read with face centered magnetic field for constrained transport
             read(Unit_Tmp, rec=iRec) Dt8, Dxyz8_D, Xyz8_D, State8_VC, &
                  B8_X, B8_Y, B8_Z
             if(UseConstrainB)then
                BxFace_BLK(1:nI+1,1:nJ,1:nK,iBlock) = B8_X
                ByFace_BLK(1:nI,1:nJ+1,1:nK,iBlock) = B8_Y
                BzFace_BLK(1:nI,1:nJ,1:nK+1,iBlock) = B8_Z
             end if
             IsRead = .true.
          endif                                       !^CFG END CONSTRAINB
          if(n_prev==n_step)then                      !^CFG IF IMPLICIT BEGIN
             ! Read with previous state for sake of implicit BDF2 scheme
             read(Unit_Tmp, rec=iRec) Dt8, Dxyz8_D, Xyz8_D, State8_VC, &
                  State8_CV
             if(UseImplicit)then
                do iVar = 1, nVar
                   ImplOld_VCB(iVar,:,:,:,iBlock) = State8_CV(:,:,:,iVar)
                end do
             end if
             IsRead = .true.
          end if                                       !^CFG END IMPLICIT
          if(.not.IsRead) &
               read(Unit_Tmp, rec=iRec) Dt8, Dxyz8_D, Xyz8_D, State8_VC

          Dt_BLK(iBlock) = Dt8
          Dx_BLK(iBlock) = Dxyz8_D(1)
          Dy_BLK(iBlock) = Dxyz8_D(2)
          Dz_BLK(iBlock) = Dxyz8_D(3)
          XyzStart_BLK(:,iBlock) = Xyz8_D
          State_VGB(1:nVar,1:nI,1:nJ,1:nK,iBlock) = State8_VC
       end if

       if(Dx_BLK(iBlock) < 0 .or. Dy_BLK(iBlock) < 0 .or. Dz_BLK(iBlock) < 0 &
            .or. Dt_BLK(iBlock) < 0)then
          write(*,*)NameSub,': corrupt restart data!!!'
          write(*,*)'iBlock  =',iBlock
          write(*,*)'Dxyz    =',Dx_BLK(iBlock), Dy_BLK(iBlock), Dz_BLK(iBlock)
          write(*,*)'Dt      =', Dt_BLK(iBlock)
          write(*,*)'XyzStart=',XyzStart_BLK(:,iBlock)
          write(*,*)'State111=',State_VGB(1:nVar,1,1,1,iBlock)
          call stop_mpi(NameSub//': corrupt restart data!!!')
       end if
    end do

    close(Unit_Tmp)

  end subroutine read_direct_restart_file

  !============================================================================

  subroutine write_direct_restart_file

    character (len=*), parameter :: NameSub='write_direct_restart_file'
    integer :: iBlock, iMorton, iRec, iVar
    !--------------------------------------------------------------------

    if(TypeRestartOutFile == 'one')then
       call open_direct_restart_file(DoRead = .false.)
    else
       ! For 'proc' type open file with processor index 
       ! and write block records in the order they are stored
       call open_direct_restart_file(DoRead = .false., iFile = iProc)
       iRec = 0
    end if

    do iBlock = 1, nBlock

       if(UnusedBlk(iBlock)) CYCLE
       ! Use the global block index as the record number
       iMorton = iMortonNode_A(iNode_B(iBlock))

       if(TypeRestartOutFile == 'proc')then
          ! Write block into next record and store info for index file
          iRec = iRec + 1
          iFileMorton_I(iMorton) = iProc
          iRecMorton_I(iMorton)  = iRec
       else
          ! For 'one' restart file record index is given by Morton index
          iRec = iMorton
       end if

       if(UseConstrainB)then                          !^CFG IF CONSTRAINB BEGIN
          ! Save face centered magnetic field 
          write(Unit_tmp, rec=iRec)  Dt_BLK(iBlock),&
               Dx_BLK(iBlock), Dy_BLK(iBlock), Dz_BLK(iBlock),&
               XyzStart_BLK(:,iBlock), &
               State_VGB(1:nVar,1:nI,1:nJ,1:nK,iBlock), &
               BxFace_BLK(1:nI+1,1:nJ,1:nK,iBlock),&
               ByFace_BLK(1:nI,1:nJ+1,1:nK,iBlock),&
               BzFace_BLK(1:nI,1:nJ,1:nK+1,iBlock)
          CYCLE
       endif                                          !^CFG END CONSTRAINB
       if(n_prev==n_step)then                         !^CFG IF IMPLICIT BEGIN
          ! Save previous time step for sake of BDF2 scheme
          write(Unit_tmp, rec=iRec) &
               Dt_BLK(iBlock), &
               Dx_BLK(iBlock), Dy_BLK(iBlock), Dz_BLK(iBlock), &
               XyzStart_BLK(:,iBlock), &
               State_VGB(1:nVar,1:nI,1:nJ,1:nK,iBlock), &
               (ImplOld_VCB(iVar,:,:,:,iBlock), iVar = 1, nVar)
          CYCLE
       endif                                          !^CFG END IMPLICIT

       write(Unit_tmp, rec=iRec) &
            Dt_BLK(iBlock), &
            Dx_BLK(iBlock), Dy_BLK(iBlock), Dz_BLK(iBlock), &
            XyzStart_BLK(:,iBlock), &
            State_VGB(1:nVar,1:nI,1:nJ,1:nK,iBlock)
    end do

    close(Unit_Tmp)

  end subroutine write_direct_restart_file

  !============================================================================

  subroutine string_append_iter(NameFile, nIter)

    character (len=*), parameter :: NameSub='string_append_iter'
    character (len=100), intent(inout) :: NameFile
    integer, intent(in) :: nIter

    ! Note: Fortran cannot write parts of a string into the same string!
    character(len=100):: NameFileOld
    integer:: i
    !--------------------------------------------------------------------
    
    if (nIter < 0) call stop_mpi(NameSub//' nIter cannot be negative')

    NameFileOld = NameFile
    i = index(NameFileOld,'/',back=.true.)
    write(NameFile,'(a,i8.8,a)') &
         NameFileOld(1:i)//'n', nIter, '_'//NameFileOld(i+1:90)

  end subroutine string_append_iter

  !===========================================================================

  subroutine write_geoind_restart

    ! Save ModGmGeoindices::MagPerturb_II to a restart file on proc 0

    use ModIO,          ONLY: Unit_Tmp
    use ModProcMH,      ONLY: iProc
    use ModGmGeoindices,ONLY: nKpMag, iSizeKpWindow, MagPerturb_II

    integer            :: i, j
    character(len=100) :: NameFile

    character(len=*), parameter :: NameSub='write_geoind_restart'
    logical :: DoTest, DoTestMe
    !------------------------------------------------------------------------
    call CON_set_do_test(NameSub, DoTest, DoTestMe)
    
    ! Ensure that restart files are only written from head node.
    if(iProc/=0) return

    ! Open restart file.
    NameFile = trim(NameRestartOutDir)//NameGeoIndFile
    open(Unit_Tmp, file=NameFile, status='REPLACE')

    ! Size of array:
    write(Unit_Tmp,*) nKpMag, iSizeKpWindow
    ! Save MagPerturb_II
    do j = 1, iSizeKpWindow
       do i = 1, nKpMag
          write(Unit_Tmp, '(es20.12)' ) MagPerturb_II(i,j)
       end do
    end do
    close(Unit_Tmp)

  end subroutine write_geoind_restart

  !===========================================================================
  subroutine read_geoind_restart

    ! Read MagPerturb_II from restart file on processor 0

    use ModIO,          ONLY: Unit_Tmp
    use ModProcMH,      ONLY: iProc
    use ModGmGeoindices,ONLY: nKpMag, iSizeKpWindow, MagPerturb_II, IsFirstCalc

    integer            :: i, j, nMagTmp, iSizeTmp
    logical            :: DoRestart
    character(len=100) :: NameFile

    character(len=*), parameter :: NameSub='read_geoind_restart'
    logical :: DoTest, DoTestMe
    !------------------------------------------------------------------------
    call CON_set_do_test(NameSub, DoTest, DoTestMe)

    NameFile = trim(NameRestartInDir)//NameGeoindFile

    ! Check for restart file.  If one exists, use it.
    inquire(file=NameFile, exist=DoRestart)
    if(.not. DoRestart) then
       write(*,*) NameSub,": WARNING did not find geoindices restart file ",&
            trim(NameFile)
       RETURN
    end if

    write(*,*)'GM: ',NameSub, ' reading ',trim(NameFile)

    open(Unit_Tmp, file=NameFile, status='OLD', action='READ')

    ! Read size of array, ensure that it matches expected.
    ! If not, it means that the restart is incompatible and cannot be used.
    read(Unit_Tmp, *) nMagTmp, iSizeTmp

    if( nMagTmp /= nKpMag .or. iSizeTmp /= iSizeKpWindow ) then
       write(*,*)'ERROR: in file ',trim(NameFile)
       write(*,*)'Restart file contains  nMagTmp, iSizeTmp=', &
            nMagTmp, iSizeTmp
       write(*,*)'PARAM.in contains nKpMag, iSizeKpWindow =', &
            nKpMag, iSizeKpWindow
       call stop_mpi(NameSub//' restart does not match Kp settings!')
    end if

    do j = 1, iSizeKpWindow
       do i = 1, nKpMag
          read(Unit_Tmp,*) MagPerturb_II(i,j)
       end do
    end do
    close(Unit_Tmp)

    IsFirstCalc=.false.

  end subroutine read_geoind_restart

end module ModRestartFile
