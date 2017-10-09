module SP_ModReadMhData

  ! This module contains methods for reading input MH data

  use SP_ModSize, ONLY: &
       nDim, nLat, nLon, nNode, &
       iParticleMin, iParticleMax, nParticle,&
       nMomentumBin, &
       Particle_, OriginLat_, OriginLon_

  use SP_ModGrid, ONLY: &
       get_node_indexes, &
       iComm, &
       nVar, nBlock, State_VIB, iGridLocal_IB, iNode_B, &
       Distribution_IIB, LogEnergyScale_I, LogMomentumScale_I, &
       DMomentumOverDEnergy_I, &
       Proc_, Begin_, End_, X_, Y_, Z_, Bx_, By_, Bz_, &
       B_, Ux_, Uy_, Uz_, U_, Rho_, T_, S_, EFlux_, &
       NameVar_V

  use ModPlotFile, ONLY: read_plot_file

  implicit none

  SAVE

  private ! except
 
  public:: &
       set_read_mh_data_param, read_mh_data, &
       DoReadMhData


  !\
  !----------------------------------------------------------------------------
  ! Format of output files
  integer, parameter:: &
       Tec_ = 0, &
       Idl_ = 1
  !----------------------------------------------------------------------------
  ! the input directory
  character (len=100):: NameInputDir=""
  ! the input file name base
  character (len=100):: NameFileBase="MH_data"
  character (len=4)  :: NameFormat
  character (len=20) :: TypeFile

  integer, parameter:: nReadVar = 11
  
  ! buffer is larger than the data needed to be read in the case 
  ! the input file has additional data
  real:: Buffer_II(nVar,nParticle)

  real:: TimeRead, TimeReadStart, TimeReadMax, DtRead
  integer:: iIterRead, iIterReadStart, DnRead

  logical:: DoReadMhData = .false.
  !/
contains
  
  subroutine set_read_mh_data_param
    use ModReadParam, ONLY: read_var
    ! set parameters of output files: file format, kind of output etc.
    character(len=300):: StringPlot
    ! loop variables
    integer:: iFile, iNode
    character(len=*), parameter :: NameSub='SP:set_read_mh_data_param'
    !--------------------------------------------------------------------------
    !
    call read_var('DoReadMhData', DoReadMhData)
    if(.not. DoReadMhData)&
         RETURN
    ! the input directory
    call read_var('NameInputDir', NameInputDir)
    ! ADD "/" IF NOT PRESENT
        
    !
    call read_var('TypeFile', TypeFile)

    ! time and iteration of the first file to be read
    call read_var('TimeReadStart',  TimeReadStart)
    call read_var('iIterReadStart', iIterReadStart)

    TimeRead = TimeReadStart
    iIterRead= iIterReadStart

    ! time step
    call read_var('DtRead', DtRead)
    call read_var('DnRead', DnRead)

    ! the format of output file must be set
    select case(trim(TypeFile))
    case('tec')
       NameFormat='.dat'
    case('idl')
       NameFormat='.out'
    case default
       call CON_stop(NameSub//': input format was not set in PARAM.in')
    end select
  end subroutine set_read_mh_data_param

  !============================================================================

  subroutine read_mh_data(TimeOut)
    real,    intent(out):: TimeOut
    ! read 1D MH data, which are produced by write_mh_1d n ModWrite
    ! separate file is read for each field line, name format is (usually)
    ! MH_data_<iLon>_<iLat>_t<ddhhmmss>_n<iIter>.{out/dat}
    !------------------------------------------------------------------------
    ! name of the input file
    character(len=100):: NameFile
    ! loop variables
    integer:: iBlock, iParticle, iVarPlot
    ! indexes of corresponding node, latitude and longitude
    integer:: iNode, iLat, iLon
    ! number of particles saved in the input file
    integer:: nParticleInput
    ! timestamp
    character(len=8):: StringTime
    !------------------------------------------------------------------------
    ! the simulation time corresponding to the input file
    TimeOut = TimeRead

    ! read the data
    do iBlock = 1, nBlock
       iNode = iNode_B(iBlock)
       call get_node_indexes(iNode, iLon, iLat)

       ! set the file name
       call get_time_string(TimeRead, StringTime)
       write(NameFile,'(a,i3.3,a,i3.3,a,i6.6,a)') &
            trim(NameInputDir)//trim(NameFileBase)//'_',iLon,'_',iLat,&
            '_t'//StringTime//'_n',iIterRead, NameFormat

       ! read the header first
       call read_plot_file(&
            NameFile   = NameFile,&
            TypeFileIn = TypeFile,&
            n1out      = nParticleInput,&
            VarOut_VI  = Buffer_II)

       State_VIB(1:nReadVar, 1:nParticleInput, iBlock) = &
            Buffer_II(1:nReadVar, 1:nParticleInput)

       iGridLocal_IB(Begin_,iBlock) = 1
       iGridLocal_IB(End_,  iBlock) = nParticleInput
    end do

    ! advance read time and iteration
    TimeRead  = TimeRead  + DtRead
    iIterRead = iIterRead + DnRead

  end subroutine read_mh_data

  !==========================================================================

  subroutine get_time_string(Time, StringTime)
    ! the subroutine converts real variable Time into a string,
    ! the structure of the string is 'ddhhmmss', 
    ! i.e shows number of days, hours, minutes and seconds 
    ! after the beginning of the simulation
    real,             intent(in) :: Time
    character(len=8), intent(out):: StringTime
    !--------------------------------------------------------------------------
    ! This is the value if the time is too large
    StringTime = '99999999'
    if(Time < 100.0*86400) &
         write(StringTime,'(i2.2,i2.2,i2.2,i2.2)') &
         int(                  Time          /86400.), & ! # days
         int((Time-(86400.*int(Time/86400.)))/ 3600.), & ! # hours
         int((Time-( 3600.*int(Time/ 3600.)))/   60.), & ! # minutes
         int( Time-(   60.*int(Time/   60.)))            ! # seconds
  end subroutine get_time_string

end module SP_ModReadMhData