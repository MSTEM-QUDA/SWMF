!This code is a copyright protected software (c) 2002- University of Michigan
!=============================================================================
subroutine write_plot_los(iFile)

  ! Purpose:  Integrate some quantities along several lines of sight and
  !           create a 2D image of the integrated quantities.
  !           The viewing point can be inifinitely far or at a finite distance.
  !           Applications include integrating density, 
  !           creating a synthetic coronagraph image of Thomson scattered 
  !           white light by integrating light scattered in the line of sight.
  !
  !           The algorithm loops over all blocks per processor (in parallel)
  !           and over lines of sight and then the results obtained on the
  !           processors are added up.
  !
  !           Written by Chip Manchester, KC Hansen
  !                   some improvements by Gabor Toth
  !                   some changes by Noe Lugaz
  !
  !           July     2001
  !           January  2002 modified for improved image plane
  !           December 2003 fixed sign error in scattering coefficient b_los
  !           January  2004 fix to accept 0 in LOS vector
  !           January  2004 fixed declaration for norm_los(3), XyzPix_D(3) 
  !           February 2004 fix integration and make 2nd order accurate
  !                         fix save_file in main.f90 update ghost cells
  !                         include forgotten plot_pars1=plot_pars(ifile)
  !                         flags for PB and LW and limb darkening parameter
  !                         improved block-line distance calculation
  !                         fix IDL output and plot filenames
  !                         use dynamic arrays and contained subroutines
  !                         exclude whole block if outside LOS image
  !                         simplify block-line distance calculation
  !                         simplify body-line distance calculation
  !                         moved plot variable loop inside line integration
  !                         dimensionalize some of the plot variables
  !           January  2006 compatibility with framework
  !                         rotation of the coordinates to HGI
  !                         wide-angle line-of-sight (for STEREO)
  !                         change in the parameters: satellite_position, 
  !                         offset_angle   
  !                         Cartesian grid and circular image centered
  !                         at the Sun (no offset angle)
  !           March    2009 Allow integration of functions different from rho
  !           Sept     2009 Edit by Cooper Downs: Added integration method
  !                         for spherical geometry, also added EUV (3-filters)
  !                         and Soft-Xray synthesis capability 

  use ModProcMH
  use ModMain, ONLY : nI, nJ, nK, n_step, time_simulation, Unused_B, &
       time_accurate, nBlock, NameThisComp,rBuffMax,TypeCoordSystem, &
       Body1,body1_, StartTime, CodeVersion
  use ModGeometry, ONLY: &
       XyzStart_BLK, TypeGeometry, IsBoundaryBlock_IB, nMirror_D
  use ModPhysics, ONLY : No2Io_V, UnitX_, No2Si_V, UnitN_, rBody, &
       UnitTemperature_
  use ModIO
  use ModAdvance, ONLY : rho_, State_VGB
  use ModNumConst, ONLY : cTiny, cUnit_DD, cTolerance
  use ModMpi
  use CON_axes, ONLY : transform_matrix
  use ModCoordTransform, ONLY : rot_matrix_z, cross_product
  use ModUtilities, ONLY: lower_case, split_string, join_string
  use ModPlotFile, ONLY: save_plot_file
  use ModParallel, ONLY: NeiLBot, NeiLTop, NOBLK
  use ModLookupTable, ONLY: i_lookup_table, interpolate_lookup_table, Table_I
  use BATL_lib, ONLY: Xyz_DNB, Xyz_DGB, CellSize_DB

  implicit none

  ! Arguments

  integer, intent(in) :: iFile

  ! Local variables
  logical :: IsRzGeometry = .false.

  integer :: iError

  ! File specific parameters
  integer :: nPix
  real    :: aOffset, bOffset, rSizeImage, rSizeImage2, rOccult, rOccult2,&
       OffsetAngle


  ! Plot variables
  integer, parameter :: neqparmax=10
  real, allocatable :: ImagePe_VII(:,:,:), Image_VII(:,:,:)

  real ::     eqpar(neqparmax)
  character (len=20) :: eqparnames(neqparmax)
  character (len=20) :: plotvarnames(nPlotVarLosMax)
  character (len=20) :: NameVar


  integer :: nEqpar, nPlotVar
  integer :: iPix, jPix             ! indexes of the pixel
  real    :: aPix, bPix             ! coordinates of pixel in the image frae
  real    :: ImageCenter_D(3)       ! 3D coordinates of the center of image
  real    :: aUnit_D(3), bUnit_D(3) ! unit vectors for the image coordinates
  real    :: LosPix_D(3)            ! unit vector from observer to pixel
  real    :: XyzPix_D(3)            ! pixel location in 3D
  real    :: rBlockSize, rBlockCenter
  real    :: SizePix, r2Pix    
  real    :: BlockDistance, ObsDistance, Ratio
  real    :: XyzBlockCenter_D(3), CellSize_D(3), aBlockCenter, bBlockCenter
  real    :: XyzBlockStart_D(3), XyzBlockSign_D(3)=1.0

  real, dimension(3,3) :: FromHgi_DD
  real, dimension(3) :: Los_D, ObsPos_D

  ! rInner in IH and rOuter in SC should be identical!
  ! rInner in SC should be smaller than the occulting radius
  ! rInner in IH should be larger than the inner boundary radius
  ! rOuter in SC should be smaller than the size of the domain
  real :: rInner, rInner2, rOuter, rOuter2

  character (LEN=500) :: allnames, StringHeadLine
  character (LEN=500) :: unitstr_TEC, unitstr_IDL
  character (LEN=10) :: unitList_HDF(nPlotVarLosMax)
  character (LEN=5) :: file_extension !changed to LEN=5 to make room for .batl
  character (LEN=40) :: file_format

  ! extra variables needed for auxiliarry data writing with tec output
  ! (style copied from write_plot_tec) 
  character (len=23) :: TextDateTime0, TextDateTime
  character (len=80) :: FormatTime
  character(len=80) :: StringTmp
  integer :: iTime0_I(7),iTime_I(7)

  ! block and variable Indices
  integer :: iBLK, iMirror, jMirror, kMirror, iVar

  logical :: oktest,oktest_me,DoTiming,DoTimingMe, DoCheckBlock
  logical :: UseScattering, UseRho

  ! variables added for sph geometry
  logical :: IsSphGeometry = .false.
  logical :: UseEuv,UseSxr
  real,dimension(3,8) :: Xyz_DN, BBoxVertex_DN

  integer :: iMid1,iMid2,iMid3,ii
  real :: dlength
  real :: FixedXyzBlockCenter_D(3) ! XyzBlockcenter changes, so need fixed one

  real ::rNodeMax,rNodeMin,CosAngle,CosAngleMin !BBox stuff
  logical :: AlignedZ = .false.

  integer :: iTableEUV = -1, iTableSXR= -1

  ! variables for reading in a generalized table
  logical :: UseTableGen = .false.
  integer :: iTableGen = -1
  character (len=20) :: TableVarNames(nPlotVarLosMax)
  integer :: nTableVar
  real, allocatable :: InterpValues_I(:)

  character(len=*), parameter :: NameSub = 'write_plot_los'
  !---------------------------------------------------------------------------

  ! Initialize stuff
  call set_oktest(NameSub, oktest, oktest_me)
  call set_oktest('los_timing', DoTiming, DoTimingMe)

  call timing_start(NameSub)

  select case(TypeGeometry)
  case('cartesian')
     IsRzGeometry  = .false.
     IsSphGeometry = .false.
  case('rz')
     IsRzGeometry = .true.
     IsSphGeometry = .false.
  case('spherical','spherical_lnr','spherical_genr')
     IsRzGeometry  = .false.
     IsSphGeometry = .true.
  case default
     call stop_mpi(NameSub//' is not implemented for TypeGeometry=' &
          //TypeGeometry)
  end select

  ! Set rInner and rOuter depending on component
  select case(NameThisComp)
  case('SC')
     rInner = rBody 
     rOuter = rBuffMax
  case('IH')
     rInner = rBuffMax
     rOuter = 1000.0
  case('GM')
     rInner = 0.0 ! needed for comet applications
     rOuter = 1e30
  end select
  rInner2 = rInner**2
  rOuter2 = rOuter**2

  if(NameThisComp == 'GM')then
     ! Do not convert to HGI
     FromHgi_DD = cUnit_DD
  else
     ! Convert to HGI
     FromHgi_DD = transform_matrix(Time_Simulation,'HGI', TypeCoordSystem)
  end if

  ! Set file specific parameters
  nPix       = n_pix_r(iFile)
  aOffset    = xOffset(iFile)
  bOffset    = yOffset(iFile)
  rSizeImage = r_size_image(iFile)
  rSizeImage2= rSizeImage**2
  rOccult    = radius_occult(iFile)
  rOccult2   = rOccult**2
  OffsetAngle= offset_angle(iFile)

  ! Rotate observation point from HGI system to the current coordinate system
  ObsPos_D    = matmul(FromHgi_DD, ObsPos_DI(:,iFile))
  ObsDistance = sqrt(sum(ObsPos_D**2))
  ! Normalize line of sight vector pointing towards the origin
  Los_D       = -ObsPos_D/ObsDistance
  ! Rotation with offset angle
  Los_D =matmul( rot_matrix_z(OffsetAngle), Los_D)
  ! Observer distance from image plane
  ObsDistance = abs(sum(ObsPos_D*Los_D))

  ! Make zero components slightly different from zero
  where(Los_D == 0.0) Los_D = cTiny

  ! Pixel size for node based pixel grid
  SizePix = 2*rSizeImage/(nPix - 1)

  if(oktest .and. iProc==0) then
     write(*,*) 'ObsPos         =',ObsPos_DI(:,ifile)
     write(*,*) 'Los_D          =', Los_D
     write(*,*) 'rSizeImage     =',rSizeImage
     write(*,*) 'aOffset,bOffset=', aOffset, bOffset
     write(*,*) 'ImageCenter_D  =',ImageCenter_D
     write(*,*) 'SizePix        =',SizePix
     write(*,*) 'nPix           =',nPix
  end if

  unitstr_TEC = ''
  unitstr_IDL = ''

  plot_type1=plot_type(ifile)
  plot_vars1=plot_vars(ifile)
  plot_pars1=plot_pars(ifile)

  if(oktest_me)write(*,*)'ifile=',ifile,' plot_type=',plot_type1, &
       ' form = ',plot_form(ifile)

  call lower_case(plot_vars1)
  call split_string(plot_vars1,nPlotVarLosMax,plotvarnames,nPlotVar)
  call split_string(plot_pars1,neqparmax,eqparnames,neqpar)
  call set_eqpar(ifile-plot_,neqpar,eqparnames,eqpar)

  ! For generalized Los Table check PlotVarNames for string 'tbl'
  UseTableGen = any(PlotVarNames(1:nPlotVar)== 'tbl')

  if(UseTableGen) then
     iTableGen = i_lookup_table(trim(NameLosTable(iFile)))
     if (iTableGen <=0) &
          call stop_mpi('Need to load #LOOKUPTABLE for TBL response!')
     ! split the variable list string read in the table
     call split_string(Table_I(iTableGen)%NameVar, nPlotVarLosMax, &
          TableVarNames, nTableVar)
     ! don't count the x and y table labels as plot variables
     nPlotVar=nTableVar-2
     PlotVarNames(1:nPlotVar)=TableVarNames(3:nTableVar)

     ! redefine plot_vars1 with correct table info
     call join_string(nPlotVar, PlotVarNames, plot_vars1)

     if(oktest_me) then
        write(*,*) 'plot variables, UseRho=', plot_vars1, UseRho
        write(*,*) 'nPlotVar, PlotVarNames_V=', &
             nPlotVar,plotvarnames(1:nPlotVar)
     end if

     ! allocate the vector that will contain the interpolated values
     if(.not.allocated(InterpValues_I)) &
          allocate(InterpValues_I(nPlotVar))

     if(oktest_me) write(*,*) 'NameVar: ', Table_I(iTableGen)%NameVar
  endif

  allnames='x y '//trim(plot_vars1)//' '//plot_pars1
  if(oktest_me) write(*,*) 'AllNames: ', AllNames

  if(oktest_me) then
     write(*,*) 'plot variables, UseRho=', plot_vars1, UseRho
     write(*,*) 'nPlotVar, PlotVarNames_V=', &
          nPlotVar,plotvarnames(1:nPlotVar)
  end if

  ! Get the headers that contain variables names and units
  select case(plot_form(ifile))
  case('tec')
     call get_TEC_los_variables(ifile,nPlotVar,plotvarnames,unitstr_TEC)
     if(oktest .and. iProc==0) write(*,*)unitstr_TEC
  case('idl')
     call get_IDL_los_units(ifile,nPlotVar,plotvarnames,unitstr_IDL, .false.)
     if(oktest .and. iProc==0) write(*,*)unitstr_IDL
  case('hdf')
     call get_IDL_los_units(ifile,nPlotVar,plotvarnames,unitstr_IDL, .true.)
     if(oktest .and. iProc==0) write(*,*)unitStr_IDL
  end select

  if(UseTableGen) then
     unitstr_TEC = 'VARIABLES = "X", "Y"'
     do iVar=1, nPlotVar
        unitstr_TEC = trim(unitstr_TEC)//', "'//trim(PlotVarNames(iVar))//'"'
     enddo
     if(oktest .and. iProc==0) write(*,*)'unitstr_TEC: ',unitstr_TEC

     if(plot_form(ifile) /= 'hdf') then
         call join_string(nPlotVar, PlotVarNames, plot_vars1)
         unitstr_IDL = 'x y '//plot_vars1
         if(oktest .and. iProc==0) write(*,*)'unitstr_IDL: ',unitstr_IDL
    end if
  endif

  ! Create unit vectors aUnit_D and bUnit_D orthogonal to the 
  ! central line of sight to setup the coordinate system in the viewing plane
  ! We use cross products of the LOS vector with one of the principal 
  ! directions (0,0,1) or (0,1,0) to make sure that the viewing plane is 
  ! aligned with the original Cartesian coordinates. In case the viewing
  ! is roughly along the X or Y axis, we want bUnit_D to point along +Z,
  ! for viewing along the Z axis, we want bUnit_D to point along +Y:
  ! a = LOS x (0,0,1), b = a x LOS ensures that b is roughly aligned with +Z
  ! a = LOS x (0,1,0), b = a x LOS ensures that b is roughly aligned with +Y
  if(abs(Los_D(3)) < maxval(abs(Los_D(1:2))))then
     aUnit_D = cross_product(Los_D, (/0.,0.,1./))
     AlignedZ = .true.
  else
     ! Viewing along the Z axis more or less
     aUnit_D = cross_product(Los_D, (/0.,1.,0./))
  end if
  aUnit_D = aUnit_D/sqrt(sum(aUnit_D**2))
  bUnit_D = cross_product(aUnit_D, Los_D)
  bUnit_D = bUnit_D/sqrt(sum(bUnit_D**2))

  ! 3D vector pointing from the origin to the image center
  ImageCenter_D = ObsPos_D + ObsDistance*Los_D &
       + aOffset*aUnit_D + bOffset*bUnit_D

  ! Make offset to be relative to the Sun (and not the projected observer)
  aOffset = dot_product(ImageCenter_D, aUnit_D)
  bOffset = dot_product(ImageCenter_D, bUnit_D)

!!!aOffset = aOffset + dot_product(ObsPos_D, aUnit_D)

  allocate( &
       ImagePe_VII(nPlotVar,nPix,nPix), &
       Image_VII(nPlotVar,nPix,nPix))

  ImagePe_VII = 0.0

  ! Do we need to apply scattering
  UseScattering = any(plotvarnames(1:nPlotVar) == 'wl') &
       .or.       any(plotvarnames(1:nPlotVar) == 'pb')

  ! Do we need to calc EUV response?
  UseEuv = any(plotvarnames(1:nPlotVar) == 'euv171') &
       .or.       any(plotvarnames(1:nPlotVar) == 'euv195') &
       .or.       any(plotvarnames(1:nPlotVar) == 'euv284')

  ! Do we need to calc Soft X-Ray response? 
  UseSxr = any(plotvarnames(1:nPlotVar) == 'sxr')

  ! if EUV or SXR calc, then get lookup table info
  if (UseEuv) iTableEUV  = i_lookup_table('euv')
  if (UseSxr) iTableSXR  = i_lookup_table('sxr')

  ! Do we need to calculate density (also for white light and polarization)
  UseRho = UseScattering .or. any(plotvarnames(1:nPlotVar) == 'rho') &
       .or. UseEuv .or. UseSxr .or. UseTableGen

  if(DoTiming)call timing_start('los_block_loop')

  ! loop over blocks
  do iBLK = 1, nBlock

     if (Unused_B(iBLK)) CYCLE

     CellSize_D = CellSize_DB(:,iBlk)

     do iMirror = 1, nMirror_D(1)
        XyzBlockSign_D(1) = 3 - 2*iMirror
        do jMirror = 1, nMirror_D(2)
           XyzBlockSign_D(2) = 3 - 2*jMirror
           do kMirror = 1, nMirror_D(3)
              XyzBlockSign_D(3) = 3 - 2*kMirror

              call integrate_block

           end do    ! kMirror
        end do    ! jMirror
     end do    ! iMirror
  end do       ! iBLK loop

  if(DoTiming)call timing_stop('los_block_loop')
  !   if(plot_form(iFile) .ne. 'hdf') then
  !       ! add up the pixels from all PE-s to root proc
  if(nProc > 1)then
     call MPI_REDUCE(ImagePe_VII, Image_VII, nPix*nPix*nPlotVar, &
          MPI_REAL, MPI_SUM, 0, iComm, iError)
  else
     Image_VII = ImagePe_VII
  end if

  if (iProc==0) then

     if(plot_dimensional(iFile)) call dimensionalize_plotvar_los

     if(DoTiming)call timing_start('los_save_plot')

     select case(plot_form(ifile))
     case('tec')
        file_extension='.dat'
     case('idl')
        file_extension='.out'
     case('hdf')
        file_extension='.batl'
     end select

     if (ifile-plot_ > 9) then
        file_format='("' // trim(NamePlotDir) // '",a,i2,a,i7.7,a)'
     else
        file_format='("' // trim(NamePlotDir) // '",a,i1,a,i7.7,a)'
     end if
    
     !the plot time is stored in the hdf5 files and displayed in VisIt.
     !if you don not include it in the filename VisIt will automacially
     !group all the los files.
     if(time_accurate .and. plot_form(ifile) /= 'hdf')then
        call get_time_string
        write(filename,file_format) &
             trim(plot_type1)//"_",&
             ifile-plot_,"_t"//trim(StringDateOrTime)//"_n",n_step,&
             file_extension
     else
        write(filename,file_format) &
             trim(plot_type1)//"_",&
             ifile-plot_,"_n",n_step,file_extension
     end if

     ! write header file

     if(plot_form(ifile)=='tec') then
        open(unit_tmp,file=filename,status="replace",IOSTAT = iError)
        if(iError /= 0)call stop_mpi(NameSub//" ERROR opening "//filename)

        write(unit_tmp,*) 'TITLE="BATSRUS: Synthetic Image"'
        write(unit_tmp,'(a)')trim(unitstr_TEC)
        write(unit_tmp,*) 'ZONE T="LOS Image"', &
             ', I=',nPix,', J=',nPix,', K=1, F=POINT'


        ! Write Auxilliary header info, which is useful for EUV images.
        ! Makes it easier to identify, and automatically process synthetic 
        ! images from different instruments/locations
        if (UseTableGen) then

           write(FormatTime,*)&
                '(i4.4,"/",i2.2,"/",i2.2,"T",i2.2,":",i2.2,":",i2.2,".",i3.3)'
           call get_date_time_start(iTime0_I)
           call get_date_time(iTime_I)
           write(TextDateTime0,FormatTime) iTime0_I
           write(TextDateTime ,FormatTime) iTime_I

           !TIMEEVENT
           write(unit_tmp,'(a,a,a)') 'AUXDATA TIMEEVENT="',trim(TextDateTime),'"'

           !TIMEEVENTSTART
           write(unit_tmp,'(a,a,a)') 'AUXDATA TIMEEVENTSTART="',trim(TextDateTime0),'"'

           !TIMESECONDSABSOLUTE     ! time in seconds since 1965 Jan 01 T00:00:00.000 UTC
           write(StringTmp,'(E20.13)')StartTime+Time_Simulation
           write(unit_tmp,'(a,a,a)') &
                'AUXDATA TIMESECONDSABSOLUTE="',trim(adjustl(StringTmp)),'"'

           !ITER
           write(StringTmp,'(i12)')n_step
           write(unit_tmp,'(a,a,a)') 'AUXDATA ITER="',trim(adjustl(StringTmp)),'"'

           !NAMELOSTABLE
           write(unit_tmp,'(a,a,a)') 'AUXDATA NAMELOSTABLE="',trim(NameLosTable(iFile)),'"'

           !HGIXYZ
           write(StringTmp,'(3(E14.6))')ObsPos_DI(:,iFile)
           write(unit_tmp,'(a,a,a)') 'AUXDATA HGIXYZ="',trim(adjustl(StringTmp)),'"'

        endif

        ! Write point values
        do iPix = 1, nPix
           aPix = (iPix - 1) * SizePix - rSizeImage
           do jPix = 1, nPix
              bPix = (jPix - 1) * SizePix - rSizeImage

              if (plot_dimensional(ifile)) then
                 write(unit_tmp,fmt="(30(E14.6))") aPix*No2Io_V(UnitX_), &
                      bPix*No2Io_V(UnitX_), Image_VII(1:nPlotVar,iPix,jPix)
              else
                 write(unit_tmp,fmt="(30(E14.6))") aPix, bPix, &
                      Image_VII(1:nPlotVar,iPix,jPix)
              end if

           end do
        end do
        close(unit_tmp)
    else
        ! description of file contains units, physics and dimension
        StringHeadLine = 'LOS integrals_var22'
        ! Write Auxilliary header info, which is useful for EUV images.
        ! Makes it easier to identify, and automatically process synthetic 
        ! images from different instruments/locations
        if (UseTableGen) then

           write(FormatTime,*)&
                '(i4.4,"/",i2.2,"/",i2.2,"T",i2.2,":",i2.2,":",i2.2,".",i3.3)'
           call get_date_time_start(iTime0_I)
           call get_date_time(iTime_I)
           write(TextDateTime0,FormatTime) iTime0_I
           write(TextDateTime ,FormatTime) iTime_I

           ! TIMEEVENT and TIMEEVENTSTART
           StringHeadLine = trim(StringHeadline)// &
                '_TIMEEVENT='//trim(TextDateTime)// &
                '_TIMEEVENTSTART='//TextDateTime0

           ! TIMESECONDSABSOLUTE    
           ! time in seconds since 1965 Jan 01 T00:00:00.000 UTC
           write(StringTmp,'(E20.13)')StartTime+Time_Simulation
           StringHeadLine = trim(StringHeadLine)//&
                '_TIMESECONDSABSOLUTE='//adjustl(StringTmp)

           ! ITER
           write(StringTmp,'(i12)')n_step
           write(StringHeadLine,'(a)')trim(StringHeadLine)//'_ITER='//&
                adjustl(StringTmp)

           ! NAMELOSTABLE
           StringHeadLine = trim(StringHeadLine)//'_NAMELOSTABLE='//&
                NameLosTable(iFile)

           ! HGIXYZ
           write(StringTmp,'(3(E14.6))')ObsPos_DI(:,iFile)
           write(StringHeadLine,'(a)')trim(StringHeadLine)//'_HGIXYZ='//&
                adjustl(StringTmp)
 
        endif

        ! Set image size and dimensionalize if necessary
        aPix = rSizeImage 
        if (plot_dimensional(ifile)) aPix = aPix * No2Io_V(UnitX_)

        select case(plot_form(ifile))
        case('idl')
           call save_plot_file(filename, &
                TypeFileIn = TypeIdlFile_I(iFile), &
                StringHeaderIn = StringHeadLine, &
                nStepIn = n_step, &
                TimeIn = time_simulation, &
                ParamIn_I = eqpar(1:neqpar), &
                NameVarIn = allnames, &
                nDimIn = 2, & 
                CoordMinIn_D = (/-aPix, -aPix/), &
                CoordMaxIn_D = (/+aPix, +aPix/), &
                VarIn_VII = Image_VII)
        case('hdf')
           call save_plot_file(filename, &
                TypeFileIn = 'hdf5', &
                StringHeaderIn = StringHeadLine, &
                nStepIn = n_step, &
                TimeIn = time_simulation, &
                ParamIn_I = eqpar(1:neqpar), &
                NameVarIn_I = PlotVarNames, &
                NameUnitsIn = unitstr_IDL,&
                nDimIn = 2, & 
                CoordMinIn_D = (/-aPix, -aPix/), &
                CoordMaxIn_D = (/+aPix, +aPix/), &
                VarIn_VII = Image_VII)
        end select
     end if
  end if  ! iProc==0
  if(DoTiming)call timing_stop('los_save_plot')

  call barrier_mpi

  deallocate(ImagePe_VII, Image_VII)

  if(UseTableGen) deallocate(InterpValues_I)

  if(oktest_me)write(*,*) NameSub,' finished'

  call timing_stop(NameSub)

contains
  !=========================================================================
  subroutine integrate_block

    if(.not.IsSphGeometry) then      

       if(IsRzGeometry)then
          ! Exclude blocks that do not intersect the Z=0 plane 
          if(nK > 1)then
             if(.not.(Xyz_DGB(z_,1,1,0,iBLK)<0 &
                  .and. Xyz_DGB(z_,1,1,nK,iBLK)>0)) RETURN
          end if
          ! Exclude blocks below the Y=0 plane
          if(Xyz_DGB(y_,1,nJ,1,iBLK)<0) RETURN
       end if

       rBlockSize = 0.5*sqrt(&
            ((nI+1)*CellSize_DB(x_,iBLK))**2 + &
            ((nJ+1)*CellSize_DB(y_,iBLK))**2 + &
            ((nK+1)*CellSize_DB(z_,iBLK))**2)

       !position of the block center
       XyzBlockCenter_D = 0.5*(Xyz_DGB(:,nI,nJ,nK,iBLK)+Xyz_DGB(:,1,1,1,iBLK))

       if(iMirror == 2) XyzBlockCenter_D(1) = -XyzBlockCenter_D(1)
       if(jMirror == 2) XyzBlockCenter_D(2) = -XyzBlockCenter_D(2)
       if(kMirror == 2) XyzBlockCenter_D(3) = -XyzBlockCenter_D(3)

       rBlockCenter = sqrt(sum(XyzBlockCenter_D**2))

       if(.not.IsRzGeometry .and. (UseEuv .or. UseSxr .or. UseTableGen)) then 
          ! in cartesian grid, the rBody boundary cuts through blocks and,
          ! since EUV plots are integrating to surface, need to make sure that
          ! interpolation does not interpolate to ghost cells filled with
          ! garbage body values. So make sure that rInner is equal to 
          ! rBody + cell diagonal width. 
          ! This way, 8 cells bounding a point along the los
          ! are guaranteed to be true_cells. Only do this for blocks on the
          ! body (doesn't affect others). Also, changing it within block loop
          ! means rInner depends on block resolution (which you want).

          rInner = rBody ! reset it with every block
          if(Body1) then
             if(IsBoundaryBlock_IB(body1_,iBLK)) rInner = rBody + &
                  sqrt(sum(CellSize_D**2))
          end if
       end if

    else ! need to do additional things to check sph blocks

       call generate_vertex_vectors(1,nI+1,1,nJ+1,1,nK+1,Xyz_DN)

       ! want middle node indexes to find center
       iMid1 = nI/2 + 1; iMid2 = nJ/2 + 1; iMid3 = nK/2 + 1         

       XyzBlockCenter_D = Xyz_DNB(:,iMid1,iMid2,iMid3,iBLK)

       if(iMirror == 2) XyzBlockCenter_D(1) = -XyzBlockCenter_D(1)
       if(jMirror == 2) XyzBlockCenter_D(2) = -XyzBlockCenter_D(2)
       if(kMirror == 2) XyzBlockCenter_D(3) = -XyzBlockCenter_D(3)

       rBlockCenter = sqrt(sum(XyzBlockCenter_D**2))


       ! Main idea behind this method is to avoid r-curvature problems by
       ! extending top (high r) block bounding vertexes by a factor such
       ! that the entire curved volume is contained in a planar volume.
       !
       ! This way only need to find the planar intersections.
       !
       ! Then in the actual integration part, can discount any points that
       ! are outside curved volume
       !
       ! The factor comes from finding the radius where the plane tangent to 
       ! the point at the center of the top curved sphere intersects the 
       ! bounding radial lines. (reduces to simple 90 degree triangle calc)

       BBoxVertex_DN = Xyz_DN
       rNodeMax = sqrt(sum(Xyz_DN(:, 8)**2))
       rNodeMin = sqrt(sum(Xyz_DN(:, 1)**2))

       ! Now want to find the maximum angular seperation between center of
       ! bounding sphere and bounding lines that intersect it
       ! check all 4 in case have non-uniform phi/theta
       ! (would still need to check 2 values if had fixed dPhi/dTheta)

       CosAngleMin = 1.0
       do ii=5,8 ! 5-8 are max r bounding vertexes
          CosAngle = sum(XyzBlockCenter_D *  Xyz_DN(:, ii)) &
               /(rBlockCenter * rNodeMax)
          CosAngleMin = min(CosAngle,CosAngleMin)
       enddo

       ! now extend each top vertex along r by this factor   
       BBoxVertex_DN(:,5:8) = BBoxVertex_DN(:, 5:8)/CosAngleMin

       !--- note that now blocks can have odd shapes, so take maximum of
       !distances from XyzBlockCenter to corners to calc rBlockSize
       rBlockSize = 0.0
       do ii=1,8
          dlength = sqrt(sum( (XyzBlockCenter_D - BBoxVertex_DN(:,ii))**2))
          rBlockSize = max(dlength,rBlockSize)
       enddo
       rBlockSize = rBlockSize + cTiny !-- just to make sure...

    end if

    FixedXyzBlockCenter_D = XyzBlockCenter_D

    if(rBlockCenter < rInner - rBlockSize) RETURN

    if(rBlockCenter > rOuter + rBlockSize) RETURN

    if(IsRzGeometry)then
       ! There are no simple checks to exclude a block in R-Z geometry
       DoCheckBlock = .false.
    else
       ! distance of block center from the observer along the LOS
       BlockDistance = dot_product(Los_D, XyzBlockCenter_D - ObsPos_D)

       ! Only blocks towards the image can be checked for exclusion easily
       DoCheckBlock = BlockDistance > 0
    end if
    if(DoCheckBlock)then
       Ratio = ObsDistance/BlockDistance
       ! 3D vector from the image center to the projected block center
       XyzBlockCenter_D = Ratio*(XyzBlockCenter_D - ObsPos_D) + ObsPos_D &
            - ImageCenter_D
       aBlockCenter = dot_product(XyzBlockCenter_D, aUnit_D)
       bBlockCenter = dot_product(XyzBlockCenter_D, bUnit_D)

       ! Project block size
       rBlockSize = rBlockSize*Ratio

       ! Check if block is inside the LOS image
       if((rSizeImage + rBlockSize)**2 < aBlockCenter**2 + bBlockCenter**2)&
            RETURN
    end if

    ! Store cell 1,1,1 coordinates
    XyzBlockStart_D = XyzStart_BLK(:,iBlk)

    ! Loop over pixels
    do jPix = 1, nPix

       ! Y position of the pixel on the image plane
       bPix = (jPix - 1) * SizePix - rSizeImage

       ! Check if block can intersect this pixel
       if(DoCheckBlock)then
          if(abs(bPix - bBlockCenter) > rBlockSize) CYCLE
       end if

       do iPix = 1, nPix

          ! X position of the pixel on the image plane
          aPix = (iPix - 1) * SizePix - rSizeImage

          ! if los is on pole, will have block degeneracy 
          !            ---> offset a 'tiny' bit
          ! (will always have this problem if nPix is odd)
          if (IsSphGeometry.and.AlignedZ) aPix = aPix + cTiny

          ! Check if block can intersect this pixel
          if(DoCheckBlock)then
             if( (aPix - aBlockCenter)**2 + (bPix - bBlockCenter)**2 > &
                  rBlockSize**2 ) CYCLE 
          end if

          r2Pix = (aPix + aOffset)**2 + (bPix + bOffset)**2
          ! Check if pixel is within occultation radius
          if( r2Pix  <= rOccult2 ) CYCLE

          r2Pix = aPix**2 + bPix**2
          ! Check if pixel is outside the circular region
          if( r2Pix > rSizeImage2 ) CYCLE 

          ! Get the 3D location of the pixel
          XyzPix_D = ImageCenter_D + aPix*aUnit_D + bPix*bUnit_D

          ! Unit vector pointing from observer to pixel center
          LosPix_D = ObsPos_D - XyzPix_D
          LosPix_D = LosPix_D/sqrt(sum(LosPix_D**2))

          ! Do not allow LOS direction to be perfectly aligned with major axes
          where(LosPix_D == 0.0) LosPix_D = cTiny

          ! Calculate contribution of this block to this pixel
          if(IsRzGeometry)then
             call integrate_los_block_rz
          elseif(IsSphGeometry) then
             call integrate_los_block_sph
          else
             call integrate_los_block
          end if

       end do ! jPix loop
    end do    ! iPix loop

  end subroutine integrate_block

  !===========================================================================
  subroutine integrate_los_block_rz

    ! 0. Set x_S to the left and right X faces,
    !    and r_S to the inner and outer Y faces of the block.
    !
    ! 1. Calculate the Y and Z coordinates of the LOS intersecting x_S 
    !    x1 = xMin and x2 = xMax and obtain the corresponding 
    !    radial distances r1 = sqrt(y1^2+z1^2) and r2=sqrt(y^2 + z^2) 
    !    and keep them if R1 or R2 is within the [rMin, rMax] interval.
    ! 
    ! 2. Calculate the intersection of the line with a circular ring of width 
    !    yMax-yMin in the Y-Z plane and obtain the corresponding X values 
    !    (up to 4) and keep the ones that are within [xMin, xMax]. 
    !    This requires the solution of 2 second order equations.
    !
    ! 3. Integrate along the 1 or 2 line segments
    !    (making sure that we integrate inside the ring!) to get the length 
    !    of the line segment.

    use ModSort,        ONLY: sort_quick

    ! maximum number of intersections between LOS and 
    ! the ring formed by rotating the block around the X axis
    ! There are six potential cross sections with the sides and inner and
    ! outer rings, but only at most 4 of these are on the block
    integer, parameter :: MaxIntersect = 6 

    ! index and number of intersections
    integer :: iIntersect, nIntersect 

    ! indexes for sorting by distance
    integer :: iSort_I(MaxIntersect) 
    integer :: iSide, iSign

    ! the axial (X) and squared radial (Y**2) coordinates of the block faces
    real :: x_S(2), r2_S(2) 
    real :: Ratio, UnitYZ_D(2), DistRmin, r2Min, r2, Dist2, Dist

    ! coordinates of the intersections
    real :: Intersect_D(3), Intersect2_D(3), Intersect_DI(3,MaxIntersect)

    ! distances of intersections from the center of the pixel
    real :: DistIntersect, DistIntersect_I(MaxIntersect) 

    logical, parameter :: DoTestPix = .false.
    !------------------------------------------------------------------------
    ! Calculate the closest approach to the origin in the Y-Z plane
    ! Normalize the Y-Z components of the LOS vector to unity
    Ratio     = 1/sqrt(sum(LosPix_D(2:3)**2))
    UnitYZ_D  = Ratio*LosPix_D(2:3)
    ! Distance to the closest approach is the projection of the pixel location
    ! to the line pointing in the LOS direction
    DistRMin = -sum(UnitYZ_D*XyzPix_D(2:3))
    ! The minimum distance squared can be obtained from the Pythagorian theorem
    r2Min        = sum(XyzPix_D(2:3)**2) - DistRmin**2

    ! The radial distance of the outer face of the block
    r2_S(2) = (0.5*(Xyz_DGB(y_,1,nJ,1,iBLK) + Xyz_DGB(y_,1,nJ+1,1,iBLK)))**2

    ! Return if the outer radius is smaller than the closest approach
    if(r2_s(2) < r2Min) RETURN

    ! The radial distance of the inner face of the block
    r2_S(1) = (0.5*(Xyz_DGB(y_,1, 0,1,iBLK) + Xyz_DGB(y_,1,   1,1,iBLK)))**2

    ! The X positions of the left and right faces of the block
    if(iMirror == 1) then
       x_S(1) = 0.5*(Xyz_DGB(x_, 0,1,1,iBLK) + Xyz_DGB(x_,   1,1,1,iBLK))
       x_S(2) = 0.5*(Xyz_DGB(x_,nI,1,1,iBLK) + Xyz_DGB(x_,nI+1,1,1,iBLK))
    else
       ! Swap signs and order of faces for mirror images
       x_S(1) = -0.5*(Xyz_DGB(x_,nI,1,1,iBLK) + Xyz_DGB(x_,nI+1,1,1,iBLK))
       x_S(2) = -0.5*(Xyz_DGB(x_, 0,1,1,iBLK) + Xyz_DGB(x_,   1,1,1,iBLK))
    end if

    ! Initialize intersection arrays
    nIntersect = 0

    ! Calculate intersection positions for the R faces
    ! There can be two intersections for both faces
    do iSide = 1, 2
       ! Distance from the closest approach to the intersection with the face
       Dist2 = r2_S(iSide) - r2Min
       if(Dist2 < 0) CYCLE ! no intersection
       Dist = sqrt(Dist2)
       ! Obtain the 3D coordinates for the two intersection points
       do iSign = -1, 1, 2
          DistIntersect = Ratio*(DistRmin + iSign*Dist)
          Intersect_D = XyzPix_D + DistIntersect*LosPix_D
          if(Intersect_D(1) > x_S(1) .and. Intersect_D(1) < x_S(2))then
             nIntersect = nIntersect + 1
             Intersect_DI(:,nIntersect)  = Intersect_D
             DistIntersect_I(nIntersect) = DistIntersect
          end if
       end do
    end do

    ! Calculate intersection positions for the X faces
    do iSide = 1, 2
       ! Distance to the intersection
       DistIntersect = (x_S(iSide) - XyzPix_D(1))/LosPix_D(1)
       Intersect_D = XyzPix_D + DistIntersect*LosPix_D
       r2 = sum(Intersect_D(2:3)**2)
       if(r2 > r2_S(1) .and. r2 < r2_S(2))then
          nIntersect = nIntersect + 1
          Intersect_DI(:,nIntersect) = Intersect_D
          DistIntersect_I(nIntersect) = DistIntersect
       end if
    end do

    if(nIntersect < 2) RETURN

    if(nIntersect > 2)then
       ! Sort intersection points by distance from pixel
       call sort_quick(nIntersect, DistIntersect_I(1:nIntersect), &
            iSort_I(1:nIntersect))
    else
       ! No need to sort two points
       iSort_I(1:2) = (/1,2/)
    end if

    ! Loop through segments connecting the consecutive intersection points
    do iIntersect = 1, nIntersect-1
       Intersect_D  = Intersect_DI(:,iSort_I(iIntersect))
       Intersect2_D = Intersect_DI(:,iSort_I(iIntersect+1))

       ! check if the radius of the midpoint is inside the block, if not CYCLE
       r2 = sum((0.5*(Intersect_D(2:3) + Intersect2_D(2:3)))**2)

       if(r2 < r2_S(1) .or. r2 > r2_S(2)) CYCLE

       call integrate_segment(Intersect_D, Intersect2_D)
    end do

  end subroutine integrate_los_block_rz

  !===========================================================================

  subroutine integrate_los_block

    ! Local variables
    integer :: i, j, k, counter
    real :: intrsct(2,3,3), face_location(2,3)
    real :: xx1, xx2, yy1, yy2, zz1, zz2
    real :: Point1_D(3), Point2_D(3)
    real :: R2Point1, R2Point2,rLine_D(3),rLine2
    real :: coeff1,coeff2,coeff3
    real :: Discr
    real :: Solution1, Solution1_D(3), Solution2, Solution2_D(3)
    logical :: IsOuter, IsGoodSolution1, IsGoodSolution2 , IsAllBehind

    real :: Tmp
    !-------------------------------------------------------------------------
    !if(DoTiming)call timing_start('los_set_plotvar')

    !x_los, y_los, z_los, r_los give the position of the point on the los
    !mu_los parameter related to the limb darkening
    !face_location give the locations of the faces of the block
    !face_location(2,3) = x1, y1, z1---x2, y2, z2 

    !Determine the location of the block faces
    xx1 = 0.50*(Xyz_DGB(x_, 0, 0, 0,iBLK)+Xyz_DGB(x_,   1,   1  , 1,iBLK))
    xx2 = 0.50*(Xyz_DGB(x_,nI,nJ,nK,iBLK)+Xyz_DGB(x_,nI+1,nJ+1,nK+1,iBLK))
    yy1 = 0.50*(Xyz_DGB(y_, 0, 0, 0,iBLK)+Xyz_DGB(y_,   1,   1,   1,iBLK))
    yy2 = 0.50*(Xyz_DGB(y_,nI,nJ,nK,iBLK)+Xyz_DGB(y_,nI+1,nJ+1,nK+1,iBLK))
    zz1 = 0.50*(Xyz_DGB(z_, 0, 0, 0,iBLK)+Xyz_DGB(z_,   1,   1,   1,iBLK))
    zz2 = 0.50*(Xyz_DGB(z_,nI,nJ,nK,iBLK)+Xyz_DGB(z_,nI+1,nJ+1,nK+1,iBLK))

    ! Swap signs and order of faces for mirror images
    if(iMirror == 2) then
       Tmp = xx2; xx2 = -xx1; xx1 = -Tmp
    end if
    if(jMirror == 2) then
       Tmp = yy2; yy2 = -yy1; yy1 = -Tmp
    end if
    if(kMirror == 2) then
       Tmp = zz2; zz2 = -zz1; zz1 = -Tmp
    end if

    face_location(1,1) = xx1
    face_location(1,2) = yy1
    face_location(1,3) = zz1
    face_location(2,1) = xx2
    face_location(2,2) = yy2
    face_location(2,3) = zz2

    !Determine where the line of sight enters and exits the block
    !loop over the number of block face pairs, face directions and coordinates
    do i=1,2       !face loop
       intrsct(i,1,1) = face_location(i,1)
       intrsct(i,2,2) = face_location(i,2)
       intrsct(i,3,3) = face_location(i,3)

       do j=1,3     !direction loop
          do k=1,3   !coordinate loop
             if (j /= k) then  
                intrsct(i,j,k) = XyzPix_D(k) + &
                     (LosPix_D(k)/LosPix_D(j)) &
                     *(face_location(i,j) - XyzPix_D(j))
             end if
          end do
       end do
    end do

    !which of the 6 points are on the block?
    counter = 0
    CHECK: do i=1,2 
       do j=1,3 
          if( (intrsct(i,j,1) >= xx1) .and. (intrsct(i,j,1) <= xx2)) then
             if( (intrsct(i,j,2) >= yy1) .and. (intrsct(i,j,2) <= yy2)) then
                if( (intrsct(i,j,3) >= zz1) .and. (intrsct(i,j,3) <= zz2)) then
                   counter = counter + 1
                   if(counter == 1) Point1_D = intrsct(i,j,:)
                   if(counter == 2) then
                      Point2_D = intrsct(i,j,:)
                      ! If point 2 is different from point 1, we are done
                      if(sum(abs(Point1_D - Point2_D)) > cTolerance) EXIT CHECK
                      ! Ignore the second point, keep checking
                      counter = 1
                   end if
                end if
             end if
          end if
       end do
    end do CHECK

    ! Check if the los cuts through the block 
    if(counter /= 2) RETURN 

    R2Point1 = sum(Point1_D**2)
    R2Point2 = sum(Point2_D**2)

    ! Check if the whole segment is inside rInner
    if( R2Point1 <= rInner2 .and. R2Point2 <= rInner2) RETURN

    ! Check if the whole segment is outside rOuter
    rLine_D = XyzPix_D - LosPix_D*dot_product(LosPix_D, XyzPix_D)
    rLine2  = sum(rLine_D**2)
    if( rLine2 > rOuter2 ) RETURN

    ! Check if there is a need to calculate an intersection

    ! Do we intersect the outer sphere
    IsOuter = R2Point1 > rOuter2 .or. R2Point2 > rOuter2

    ! Do we intersect the inner or outer spheres
    if( IsOuter .or. &
         (rLine2 < rInner2 .and. rBlockCenter < rInner+rBlockSize) ) then

       coeff1 = sum((Point2_D - Point1_D)**2)
       coeff2 = 2*dot_product(Point1_D, Point2_D - Point1_D)

       if( IsOuter ) then
          coeff3 = R2Point1 - rOuter2
       else
          coeff3 = R2Point1 - rInner2
       end if

       Discr = coeff2**2-4*coeff1*coeff3

       if(Discr < 0.0)then
          write(*,*)'Warning: Discr=',Discr
          !   call stop_mpi("Negative discriminant")
          RETURN
       end if

       ! Line of sight tangent to the outer sphere
       if(IsOuter.AND.Discr==0.0)RETURN

       ! Find the two intersections (distance from point1 towards point2)
       Discr = sqrt(Discr)
       Solution1 = (-coeff2-Discr)/(2*coeff1)
       Solution2 = (-coeff2+Discr)/(2*coeff1)

       Solution1_D = Point1_D + (Point2_D - Point1_D) * Solution1
       Solution2_D = Point1_D + (Point2_D - Point1_D) * Solution2


       ! Check if the solutions are within the segment
       IsGoodSolution1 = (Solution1 >= 0.0 .and. Solution1 <= 1.0)
       IsGoodSolution2 = (Solution2 >= 0.0 .and. Solution2 <= 1.0)

       if(IsOuter)then
          ! For outer sphere replace
          ! outlying point1 with solution1 and
          ! outlying point2 with solution2
          if(R2Point1 > rOuter2) then
             if(IsGoodSolution1)then
                Point1_D = Solution1_D
             else
                RETURN
             end if
          end if
          if(R2Point2 > rOuter2) then
             if(IsGoodSolution2)then
                Point2_D = Solution2_D
             else
                RETURN
             end if
          end if
       else
          ! For inner sphere replace 
          ! internal point1 with solution2 and 
          ! internal point2 with solution1
          if(R2Point1 < rInner2) Point1_D = Solution2_D
          if(R2Point2 < rInner2) Point2_D = Solution1_D
          ! Weird case: the segment cuts the inner sphere
          if(IsGoodSolution1 .and. IsGoodSolution2)then
             ! Need to do two integrals:
             ! from point1 to solution1 and
             ! from point2 to solution2
             if(Discr > 0.0)then
                if(Solution1 > cTiny) &
                     call integrate_segment(Point1_D, Solution1_D)
                if(solution2< 1 - cTiny) &
                     call integrate_segment(Point2_D, Solution2_D)
                RETURN
             end if
          end if

       end if
    end if

    ! remove backside of sun from EUV images
    if(UseEuv.or.UseSxr.or.UseTableGen) then 
       call los_cut_backside(Point1_D, Point2_D,IsAllBehind)
       ! don't continue if all on backside
       if(IsAllBehind) RETURN
    endif

    call integrate_segment(Point1_D, Point2_D)

  end subroutine integrate_los_block

  !===========================================================================

  subroutine integrate_los_block_sph

    ! Local variables
    real :: Xyz1_D(3), Xyz2_D(3), rInside, rOutside

    logical, dimension(2) :: IsPoleNS
    logical :: IsIntersect, IsAllBehind
    !------------------------------------------------------------------------
    ! essentially a more general version of the cartesian version
    ! except this time made each part into its own subroutine
    ! note, the 3D location of the pixel is XyzPix_D
    ! need to make sure you discount the non-zero face on a polar block 
    ! use same check as fix_axis routines
    IsIntersect=.false.
    IsPoleNS = .false.
    IsPoleNS(1) = (NeiLTop(iBLK) == NOBLK)     
    IsPoleNS(2) = (NeiLBot(iBLK) == NOBLK)

    ! Block level intersection call
    ! note BBoxVertex_V is calculated in main routine block loop and is 8 vertex 
    ! locations of the smallest 6 sided planar volume that bounds the curved block
    ! (slightly larger than the block itself)
    !
    ! this function finds the points where the los intersects this volume

    call find_intersect_general(BBoxVertex_DN,IsPoleNS,IsIntersect,Xyz1_D,Xyz2_D)

    ! NOW CALL SERIES OF ROUTINES that trim the LOS integral to 
    ! the correct limits within the blocks.
    !
    ! the order is as follows:
    !
    ! a) los_cut_backside  **trim if los hits sun, only take half of domain facing observer
    ! b) los_cut_rmax      **trim if los is outside block rmax (node r boundary)
    ! c) los_cut_rmin      **trim if los is below block rmin (node r boundary),
    !                        this can branch if double cut.
    !                        call integrate segment from los_cut_rmin

    if (.not.IsIntersect) RETURN ! return if no intersection

    ! cut off any part of los behind the sun,
    ! trim to hemisphere towards observer
    call los_cut_backside(Xyz1_D,Xyz2_D,IsAllBehind)
    if(IsAllBehind) RETURN ! if this part los is entirely behind sun return

    ! Determine minimum bounding radii for intersection
    ! (either simulation limits or block limits)
    rInside = max(rInner, rNodeMin)
    rOutside = min(rOuter, rNodeMax)

    ! call nested functions to trim between max and min radii,
    ! which then call integrate segment
    call los_cut_rmax(Xyz1_D, Xyz2_D, rInside, rOutside)

    RETURN

  end subroutine integrate_los_block_sph
  !===========================================================================

  subroutine integrate_segment(XyzStart_D, XyzEnd_D)

    ! Integrate variables from XyzStart_D to XyzEnd_D
    ! The line is split into nSegment segments of length Ds

    use ModAdvance,     ONLY: UseElectronPressure
    use ModInterpolate, ONLY: bilinear, trilinear
    use ModUser,        ONLY: user_set_plot_var
    use ModParallel,    ONLY: NeiLWest, NeiLEast, NOBLK
    use ModVarIndexes,  ONLY: Pe_, p_
    use BATL_lib,       ONLY: xyz_to_coord

    real, intent(in) :: XyzStart_D(3), XyzEnd_D(3)

    integer :: iSegment, nSegment
    real :: x_q, y_q, z_q, q_mag
    real :: a_los, b_los, c_los, d_los
    real :: SinOmega, CosOmega, Cos2Theta, Sin2Omega, Cos2Omega, Logarithm

    real :: Ds             ! Length of line segment
    real :: XyzLos_D(3)    ! Coordinate of center of line segment    
    real :: xLos, yLos, zLos, rLos ! Coordinates and radial distance
    real :: CoordNorm_D(3) ! Normalized coordinates of current point
    real :: Rho            ! Density at the point
    real :: Value          ! Value of the LOS variable at the point

    ! Variables for user defined LOS variables
    integer :: iBlockLast = -1, iVarLast = -1
    logical :: IsFound, UseBody
    character(len=1):: NameTecVar, NameTecUnit, NameIdlUnit
    real    :: ValueBody
    real, allocatable, save:: PlotVar_GV(:,:,:,:)

    ! Added for EUV synth and sph geometry
    real :: GenLos_D(3)
    real :: Temp            ! Electron Temp at the point
    real :: MuGas = 0.5    ! mean molecular wieght of plasma
    real :: LogTemp, LogNe, rConv, ResponseFactor, EuvResponse(3), SxrResponse(2)
    real :: Temp_G(MinI:MaxI,MinJ:MaxJ,MinK:MaxK)

    ! this is so can modify amount of block sent to interpolation routine
    integer :: iMin, iMax
    logical :: IsNoBlockInner = .false.
    logical :: IsNoBlockOuter = .false.

    ! parameters for temperature cuttoff of EUV/SXR response
    ! idea is to neglect most of the broadened transition region
    ! since broadening introduces unphysical column depth (by orders of
    ! magnitude) which can cause it to be large enough to produce an
    ! unwanted contribution
    real :: TeCutSi = 4.0e+5
    real :: DeltaTeCutSi = 3.0e+4
    real :: FractionTrue

    !------------------------------------------------------------------------
    ! Number of segments for an accurate integral
    if (IsSphGeometry) then
       ! in gen coords, hard to think of equally weighted length
       ! (along all 3 axes), so choose n=nI+nJ+nK for now, note that
       ! CellSize_D has gencoord deltas

       nSegment = nI+nJ+nK
    elseif (IsRzGeometry) then
       ! In RZ geometry Delta Y is representative for the radial resolution
       nSegment = 1 + sum(abs(XyzEnd_D - XyzStart_D) &
            / (/ CellSize_D(1), CellSize_D(2), CellSize_D(2) /) )
    else
       nSegment = 1 + sum(abs(XyzEnd_D - XyzStart_D)/CellSize_D)
    end if

    ! Length of a segment
    Ds = sqrt(sum((XyzEnd_D - XyzStart_D)**2)) / nSegment

    ! Don't want to divide block states repeatedly in nSegment loop
    if(UseEuv .or. UseSxr .or. UseTableGen)then
       ! Fully ionized hydrogen plasma only for now.
       if(UseElectronPressure)then
          Temp_G = State_VGB(Pe_,:,:,:,iBlk)/State_VGB(Rho_,:,:,:,iBlk)
       else
          ! Fixed mean molecular weight, mu, and electron/ion Temperature
          ! equilibrium.
          Temp_G = MuGas*State_VGB(P_,:,:,:,iBlk)/State_VGB(Rho_,:,:,:,iBlk)
       end if
    end if

    do iSegment = 1, nSegment
       XyzLos_D = XyzStart_D &
            + (iSegment - 0.5)/nSegment*(XyzEnd_D - XyzStart_D)
       rLos = sqrt(sum(XyzLos_D**2))
       xLos = XyzLos_D(1)
       yLos = XyzLos_D(2)
       zLos = XyzLos_D(3)

       if(UseScattering .and. rLos > 1.0)then
          ! This calculation is useful for light scattering in SC and IH
          ! as it assumes that the radiation comes from a central 
          ! body with radius 1. Normally setting rOccult > 1 ensures rLos > 1.
          SinOmega = 1.0/rLos
          Sin2Omega = SinOmega**2
          Cos2Omega = 1 - Sin2Omega
          CosOmega = sqrt(Cos2Omega)
          Logarithm = log((1.0 + SinOmega)/CosOmega)  

          !omega and functions of omega are unique to a given line of sight
          a_los = CosOmega*Sin2Omega
          b_los = -0.125*( 1.0 - 3.0*Sin2Omega - (Cos2Omega/SinOmega)* &
               (1.0 + 3.0*Sin2Omega)*Logarithm )
          c_los = 4.0/3.0 - CosOmega - (1.0/3.0)*CosOmega*Cos2Omega
          d_los = 0.125*( 5.0 + Sin2Omega - (Cos2omega/SinOmega) * &
               (5.0 - Sin2Omega)*Logarithm )

          z_q =   (LosPix_D(1)**2 + LosPix_D(2)**2)*zLos            &
               - LosPix_D(3)*(LosPix_D(1)*xLos + LosPix_D(2)*yLos)
          x_q = xLos + (LosPix_D(1)/LosPix_D(3)) * (z_q - zLos)
          y_q = yLos + (LosPix_D(2)/LosPix_D(3)) * (z_q - zLos)
          q_mag = sqrt(x_q**2 + y_q**2 + z_q**2)

          Cos2Theta = (q_mag/rLos)**2
       end if

       ! Calculate normalized position
       ! XyzStart contains the coordinates of cell 1,1,1, hence add 1
       if(IsRzGeometry)then
          ! Radial distance is sqrt(yLos**2+zLos**2)
          CoordNorm_D(1:2) = &
               ( (/xLos*XyzBlockSign_D(1), sqrt(yLos**2+zLos**2) /) &
               - XyzBlockStart_D(1:2) )/CellSize_D(1:2) + 1
          CoordNorm_D(3) = 0.0

       elseif(IsSphGeometry) then
          ! get gen coord of los (note XyzStart_D is already in gen. coord)
          call xyz_to_coord(XyzBlockSign_D*XyzLos_D, GenLos_D)
          CoordNorm_D = (GenLos_D - XyzBlockStart_D)/CellSize_D + 1

          ! need to know if no block neighbor 
          ! (ghost cells along this edge will be wrong)
          IsNoBlockInner = (NeiLEast(iBLK) == NOBLK)     
          IsNoBlockOuter = (NeiLWest(iBLK) == NOBLK)

       else
          CoordNorm_D = &
               (XyzBlockSign_D*XyzLos_D - XyzBlockStart_D)/CellSize_D + 1
       end if

       ! interpolate density if it is needed by any of the plot variables
       if(UseRho)then
          if(nK == 1)then
             Rho = bilinear(State_VGB(Rho_,:,:,1,iBlk), &
                  MinI,MaxI, MinJ,MaxJ, CoordNorm_D(1:2))
          elseif (IsSphGeometry) then
             iMin = -1; iMax = nI+2
             if (IsNoBlockInner) iMin=1
             if (IsNoBlockOuter) iMax=nI
             Rho = trilinear(State_VGB(Rho_,iMin:iMax,:,:,iBlk), &
                  iMin, iMax, MinJ,MaxJ, MinK,MaxK,&
                  CoordNorm_D, DoExtrapolate=.true.)
          else
             Rho = trilinear(State_VGB(Rho_,:,:,:,iBlk), &
                  MinI,MaxI, MinJ,MaxJ, MinK,MaxK, CoordNorm_D)
          end if
       end if

       if(UseEuv.or.UseSxr.or.UseTableGen)then

          ! need to interpolate electron temperature. Should really be calling
          ! user_material_properties, but would need user to have implemented
          ! this.

          if(nK == 1)then
             Temp = bilinear(Temp_G(:,:,1), MinI,MaxI, MinJ,MaxJ, &
                  CoordNorm_D(1:2))
          else if (IsSphGeometry) then
             Temp = trilinear(Temp_G(iMin:iMax,:,:), &
                  iMin, iMax, MinJ,MaxJ, MinK,MaxK, &
                  CoordNorm_D, DoExtrapolate=.true.)
          else
             Temp = trilinear(Temp_G(:,:,:), MinI,MaxI, MinJ,MaxJ, MinK,MaxK, &
                  CoordNorm_D)
          end if

          ! Note this is log base 10!!
          LogTemp = log10(max(Temp*No2Si_V(UnitTemperature_), & 
               cTolerance))

          ! Here calc log base 10 of electron density, the -6 is to convert to CGS
          LogNe = log10(max(Rho*No2Si_V(UnitN_),cTolerance)) - 6.0

          ! rconv converts solar radii units to CGS for response function
          ! exponent      
          rConv = log10(6.96) + 10.0

          ! calculate Ne**2 and Normalize units (10 ^ an exponent)
          ResponseFactor = 10.0**(2.0*LogNe + rConv - 26.0)

          ! calculate Temp cuttoff function to neglect widened Trans region
          FractionTrue = 0.5*(1.0 + tanh((10**LogTemp - TeCutSi)/DeltaTeCutSi))

          if (UseEuv) then
             ! now interpolate EUV response values from a lookup table
             if (iTableEUV <=0) &
                  call stop_mpi('Need to load #LOOKUPTABLE for EUV response!')
             call interpolate_lookup_table(iTableEUV, LogTemp, LogNe, &
                  EuvResponse, DoExtrapolate=.true.)
             EuvResponse = EuvResponse * FractionTrue
          end if

          if (UseSxr) then
             ! now interpolate SXR response values from a lookup table
             if (iTableSXR <=0) &
                  call stop_mpi('Need to load #LOOKUPTABLE for SXR response!')
             call interpolate_lookup_table(iTableSXR, LogTemp, LogNe, &
                  SxrResponse, DoExtrapolate=.true.)
             SxrResponse = SxrResponse * FractionTrue
          end if

          if (UseTableGen) then
             if(iTableGen <= 0) &
                  call stop_mpi('Need to load #LOOKUPTABLE for '//NameLosTable(iFile)//' response!')
             ! now interpolate the entire table
             call interpolate_lookup_table(iTableGen, LogTemp, LogNe, &
                  InterpValues_I, DoExtrapolate=.true.)
             InterpValues_I = InterpValues_I * FractionTrue
          endif

       end if

       ! if using a generalized table can do it vector style
       if(UseTableGen) then
          ImagePe_VII(:,iPix,jPix) = ImagePe_VII(:,iPix,jPix) + &
               InterpValues_I*ResponseFactor*Ds
          CYCLE !cycle the nSegment loop
       endif

       do iVar = 1, nPlotVar
          Value = 0.0 ! initialize to 0 so that if statements below work right
          NameVar = plotvarnames(iVar)
          select case(NameVar)
          case ('len')
             ! Integrate the length of the integration lines
             Value = 1.0

          case('wl')
             ! White light with limb darkening
             if(rLos > 1.0) Value = Rho*( &
                  (1 - mu_los)*(2*c_los - a_los*Cos2Theta) &
                  + mu_los*(2*d_los - b_los*Cos2Theta) )

          case('pb')
             ! Polarization brightness
             if(rLos > 1.0) Value = &
                  Rho*( (1.0 - mu_los)*a_los + mu_los*b_los)*Cos2Theta

          case('euv171')
             ! EUV 171
             Value = EuvResponse(1)*ResponseFactor

          case('euv195')
             ! EUV 195
             Value = EuvResponse(2)*ResponseFactor

          case('euv284')
             ! EUV 284
             Value = EuvResponse(3)*ResponseFactor

          case('sxr')
             ! Soft X-Ray (Only one channel for now, can add others later)
             Value = SxrResponse(1)*ResponseFactor

          case('rho')
             ! Simple density integral
             Value = Rho

          case('sphere10')
             ! Sphere of radius 10 with 100-r^2 density profile
             Value = max(0.0, 100.0 - rLos**2)

          case('cube10')
             ! 20x20x20 cube centered around X=Y=Z=10
             Value = product( 0.5 + sign(0.5, 10.0 - abs(XyzLos_D-10.0)) )

          case default
             ! Obtain user defined plot function for the whole block
             if(iBlk /= iBlockLast .or. iVar > iVarLast)then
                iBlockLast = iBlk
                iVarLast   = iVar
                if(.not.allocated(PlotVar_GV)) &
                     allocate(PlotVar_GV(MinI:MaxI,MinJ:MaxJ,MinK:MaxK,nPlotVar))
                call user_set_plot_var(iBlk, NameVar, &
                     plot_dimensional(iFile), &
                     PlotVar_GV(:,:,:,iVar), &
                     ValueBody, UseBody, NameTecVar, NameTecUnit, NameIdlUnit,&
                     IsFound)
                if(.not. IsFound)then
                   PlotVar_GV(:,:,:,iVar)=-7777.
                   if(iProc==0.and.iBLK==1)write(*,*) &
                        NameSub, ' WARNING: unknown plotvarname=', NameVar
                end if
             end if
             ! Interpolate value
             if(nK == 1)then
                Value = bilinear(PlotVar_GV(:,:,1,iVar), &
                     MinI,MaxI, MinJ,MaxJ, CoordNorm_D(1:2))
             else
                Value = trilinear(PlotVar_GV(:,:,:,iVar), &
                     MinI,MaxI, MinJ,MaxJ, MinK,MaxK, CoordNorm_D)
             end if
          end select

          ImagePe_VII(iVar,iPix,jPix) = ImagePe_VII(iVar,iPix,jPix) + Value*Ds

       end do ! iVar

    end do !line segment interation loop 

  end subroutine integrate_segment

  !==========================================================================

  subroutine dimensionalize_plotvar_los

    use ModPhysics, ONLY : No2Si_V, UnitX_, UnitRho_
    !--------------------------------------------------------------------------

    do iVar = 1, nPlotVar
       NameVar = plotvarnames(iVar)

       select case(NameVar)
       case ('len')
          Image_VII(iVar,:,:) = Image_VII(iVar,:,:)*No2Si_V(UnitX_)
       case('rho')
          Image_VII(iVar,:,:) = Image_VII(iVar,:,:) &
               *No2Si_V(UnitRho_)*No2Si_V(UnitX_)
       case('wl','pb')
          ! do nothing for backwards compatibility
       case('euv171','euv195','euv284','sxr')
          ! do nothing since already taken care of
       case default
          ! User defined functions are already dimensional, but integral
          ! requires a multiplication by length unit
          Image_VII(iVar,:,:) = Image_VII(iVar,:,:)*No2Si_V(UnitX_)
       end select

    end do ! iVar

  end subroutine dimensionalize_plotvar_los

  !==========================================================================

  subroutine generate_vertex_vectors(i1,i2,j1,j2,k1,k2,Vertex_DN)

    ! build an array containing the 8 vertex vectors bounding a cell/block
    ! made a routine to make the interesct routine simpler
    ! also wrote it explicitly so its easy to see which vertex is which

    integer, intent(in) :: i1,i2,j1,j2,k1,k2
    real, dimension(3,8), intent(out) :: Vertex_DN
    !----------------------------------------------------------------------

    Vertex_DN(:,1) = Xyz_DNB(:,i1,j1,k1,iBlk)
    Vertex_DN(:,2) = Xyz_DNB(:,i1,j1,k2,iBlk)
    Vertex_DN(:,3) = Xyz_DNB(:,i1,j2,k1,iBlk)
    Vertex_DN(:,4) = Xyz_DNB(:,i1,j2,k2,iBlk)
    Vertex_DN(:,5) = Xyz_DNB(:,i2,j1,k1,iBlk)
    Vertex_DN(:,6) = Xyz_DNB(:,i2,j1,k2,iBlk)
    Vertex_DN(:,7) = Xyz_DNB(:,i2,j2,k1,iBlk)
    Vertex_DN(:,8) = Xyz_DNB(:,i2,j2,k2,iBlk)

  end subroutine generate_vertex_vectors

  !==========================================================================

  subroutine find_intersect_general(Vertex_DN,IsPoleNS,IsIntersect,Xyz1_D,Xyz2_D)

    ! subroutine to find general plane interections for finding if los interescts
    ! a block

    !--- in non-cartesian geometry the face normals do not have only one
    !--- component so need to use a more general intersection
    !--- calculation, do this here

    !--- calc normals first... look at xyzC definitions to see locations of
    !--- vertices. Sign (pointing in or out) and length cancel/divide out later

    real,dimension(3, 8), intent(in) :: Vertex_DN ! 8 vertexes in XYZ
    logical, intent(in) :: IsPoleNS(2) ! array to take out zero-area face on the pole

    logical, intent(out) :: IsIntersect ! Flag to see if intersection is on the cell/block
    real, dimension(3), intent(out) :: Xyz1_D, Xyz2_D ! points that intersect on the cell/block

    real, dimension(3,6) :: FaceNormal_DS, NewIntersect_DN
    integer,parameter,dimension(3,2,6) :: TriIndex_DIS=reshape((/&
         1,2,3,& ! :,1,1
         4,2,3,& ! :,2,1
         1,2,5,& ! :,1,2
         6,2,5,& ! :,2,2
         1,3,5,& ! :,1,3
         7,3,5,& ! :,2,3
         8,7,6,& ! :,1,4
         5,7,6,& ! :,2,4
         8,7,4,& ! :,1,5
         3,7,4,& ! :,2,5
         8,6,4,& ! :,1,6
         2,6,4 & ! :,2,6
         /),(/3,2,6/))
    integer :: iSide, j, iCounter, iFace
    logical, dimension(6) :: IsBadFace_S
    real :: Coeff1

    logical :: IsOnTriangle

    ! REST OF VARIBLES HERE ARE DEFINED IN parent write_plot_los subroutine!
    ! (eg LosPix_D etc.)

    FaceNormal_DS(:,1)=cross_product((Vertex_DN(:, 2)-Vertex_DN(:, 1)),(Vertex_DN(:, 3)-Vertex_DN(:, 1)))
    FaceNormal_DS(:,2)=cross_product((Vertex_DN(:, 2)-Vertex_DN(:, 1)),(Vertex_DN(:, 5)-Vertex_DN(:, 1)))
    FaceNormal_DS(:,3)=cross_product((Vertex_DN(:, 3)-Vertex_DN(:, 1)),(Vertex_DN(:, 5)-Vertex_DN(:, 1)))
    FaceNormal_DS(:,4)=cross_product((Vertex_DN(:, 7)-Vertex_DN(:, 8)),(Vertex_DN(:, 6)-Vertex_DN(:, 8)))
    FaceNormal_DS(:,5)=cross_product((Vertex_DN(:, 7)-Vertex_DN(:, 8)),(Vertex_DN(:, 4)-Vertex_DN(:, 8)))
    FaceNormal_DS(:,6)=cross_product((Vertex_DN(:, 6)-Vertex_DN(:, 8)),(Vertex_DN(:, 4)-Vertex_DN(:, 8)))

    LosPix_D = ObsPos_D - XyzPix_D
    LosPix_D = LosPix_D/sqrt(sum(LosPix_D**2))
    where(LosPix_D ==0.0) LosPix_D = cTiny

    IsBadFace_S(:) = .false.

    do iSide = 1,6 !-- loop over faces
       !-- this is a simple vector geometry formua for calculating the
       !intersection of a plane (specified by a normal and a point on
       !the plane) with a line (LosPix_D in this case)
       !-- used this form from numerical recipes 3rd edition eq 21.4.14
       ! and 21.4.15

       if (iSide < 4) iFace = 1  !-- specify a point on these planes (either pt 1 or 8) 
       if (iSide > 3) iFace = 8

       ! SouthPole
       if ((iSide == 3) .and. (IsPoleNS(2))) then
          IsBadFace_S(iSide) = .true.
          CYCLE
       endif
       ! NorthPole
       if ((iSide == 6) .and. (IsPoleNS(1))) then
          IsBadFace_S(iSide) = .true.
          CYCLE
       endif

       coeff1 = sum(LosPix_D(:) * FaceNormal_DS(:, iSide))

       if (abs(coeff1) < cTolerance) then 
          IsBadFace_S(iSide) = .true.
          CYCLE
       endif

       !--- calc the 3D point of intersection with the line and this plane
       NewIntersect_DN(:, iSide) = &
            XyzPix_D(:) + LosPix_D(:) * &
            (sum(Vertex_DN(:, iFace) * FaceNormal_DS(:,iSide)) -&
            sum(XyzPix_D * FaceNormal_DS(:,iSide))           ) / coeff1

    end do



    IsIntersect = .false.

    !which of the 6 points are on the block?
    iCounter = 0
    CHECK3: do iSide = 1,6 
       do j=1,2


          !This Method checks intersection with face the faces by dividing
          !them into 2 triangles and calculating if the los intersects them
          !
          !This is completely general xyz method, do not have to check with
          !block coordinate min and maxes... However need to be careful
          !if generalized coordinate is defining non-parallel surfaces. If a bounding
          !surface is curved (e.g. constant r surface) then planes defined by
          !the block corners may actually bound OUTSIDE the block limits 
          !(including ghost cells). This will only happen if there is a high 
          !degree of relative curvature (i.e. transition region grid)
          ! 
          ! To circumvent this problem, need to make bounding planes contain
          ! the ENTIRE volume (i.e. extend R for top vertexes) and then cut 
          ! the los to be within the general coordinate range (in later
          ! routines)

          if (IsBadFace_S(iSide)) CYCLE

          IsOnTriangle = is_on_triangle(NewIntersect_DN(:, iSide),&
               Vertex_DN(:, TriIndex_DIS(1,j,iSide)),&
               Vertex_DN(:, TriIndex_DIS(2,j,iSide)),&
               Vertex_DN(:, TriIndex_DIS(3,j,iSide)) )
          if (IsOnTriangle) then
             iCounter = iCounter + 1
             if(iCounter == 1) Xyz1_D = NewIntersect_DN(:, iSide)
             if(iCounter == 2) then
                Xyz2_D = NewIntersect_DN(:, iSide)
                ! If point 2 is different from point 1, we are done
                if(sum(abs(Xyz1_D - Xyz2_D)) > cTolerance) EXIT CHECK3
                ! Ignore the second point, keep checking
                iCounter = 1
             end if
          end if
       end do !--- end j loop
    end do CHECK3

    if (iCounter == 2) IsIntersect = .true.

  end subroutine find_intersect_general

  !==========================================================================

  logical function is_on_triangle(XyzIn_D,aXyz_D,bXyz_D,cXyz_D)

    real, dimension(3), intent(in) :: XyzIn_D,aXyz_D,bXyz_D,cXyz_D
    real, dimension(3) :: A1_D,B1_D,Q1_D
    real :: A2, B2, ACrossB2, Alpha, Beta, Gamma
    !--------------------------------------------


    !--- this function is for calclating if point on plane defined by a triangle
    !--- is within the triangle

    is_on_triangle = .false.

    if(sum(abs(aXyz_D - bXyz_D))<cTolerance) RETURN
    if(sum(abs(aXyz_D - cXyz_D))<cTolerance) RETURN
    if(sum(abs(bXyz_D - cXyz_D))<cTolerance) RETURN

    !\
    !A1, B1, Q1 are the radius vectors with respect to C vertex
    !/
    A1_D =  aXyz_D - cXyz_D
    B1_D =  bXyz_D - cXyz_D
    Q1_D = XyzIn_D - cXyz_D

    A2  = sum(A1_D**2)
    B2  = sum(B1_D**2)

    !\
    !Calculate [a\times b]^2
    !/

    ACrossB2 = A2*B2 - sum(A1_D*B1_D)**2

    Alpha = (B2 * sum(A1_D * Q1_D)-sum(A1_D * B1_D)*sum(B1_D * Q1_D) ) / ACrossB2
    Beta  = (A2 * sum(B1_D * Q1_D)-sum(A1_D * B1_D)*sum(A1_D * Q1_D) ) / ACrossB2
    Gamma = 1.0 - Alpha - Beta

    is_on_triangle = Alpha >= 0.0 .and.Beta >= 0.0 .and.Gamma >= 0.0

  end function is_on_triangle

  !==========================================================================

  subroutine los_cut_backside(Xyz1_D,Xyz2_D,IsAllBehind)

    real, dimension(3), intent(inOut) :: Xyz1_D,Xyz2_D
    logical, intent(out) :: IsAllBehind
    logical :: IsBehind1, IsBehind2

    IsAllBehind = .false.

    ! check if pixel intersects the solar disk, if not then return
    if(r2Pix > rInner2) RETURN

    ! check if either are behind the sun (dot product will be negative if so)
    IsBehind1 = (sum(Xyz1_D * ObsPos_D) < 0.0)
    IsBehind2 = (sum(Xyz2_D * ObsPos_D) < 0.0)

    ! *** NOTE XyzPix_D is the 3D position along the pixel LOS that lies 
    ! on the plane intersecting the sun center and perp to observer
    ! ---> perfect for trimming intersection to plane with the hemisphere
    ! towards the observer. 

    if(IsBehind1) Xyz1_D = XyzPix_D

    if(IsBehind2) Xyz2_D = XyzPix_D

    ! if both are behind, will not need the LOS
    IsAllBehind = IsBehind1.and.IsBehind2

  end subroutine los_cut_backside

  !==========================================================================

  subroutine los_cut_rmin(Xyz1In_D,Xyz2In_D,rInside)

    !Input parameters: coordinates for two points of intersection of
    !the given LOS with the block boundary
    real, dimension(3), intent(in) :: Xyz1In_D,Xyz2In_D
    real, intent(in) :: rInside

    real, dimension(3) :: Xyz1_D, Xyz2_D
    real :: R2Point1, R2Point2,rLine_D(3),rLine2
    real :: Coeff1,Coeff2,Coeff3
    real :: Discr
    real :: Solution1, Solution1_D(3), Solution2, Solution2_D(3)
    logical :: IsGoodSolution1, IsGoodSolution2
    real :: rInside2
    !----------------------------

    rInside2 = rInside**2

    Xyz1_D = Xyz1In_D
    Xyz2_D = Xyz2In_D

    R2Point1 = sum(Xyz1_D**2)
    R2Point2 = sum(Xyz2_D**2)

    ! Check if the whole segment is inside rInside
    if( R2Point1 <= rInside2 .and. R2Point2 <= rInside2) RETURN

    rLine_D = XyzPix_D - LosPix_D * sum(LosPix_D * XyzPix_D)
    rLine2  = sum(rLine_D**2)

    ! Check if there is a need to calculate an intersection

    ! Do we intersect the inner sphere
    if( rLine2 < rInside2 ) then

       Coeff1 = sum((Xyz2_D - Xyz1_D)**2)
       Coeff2 = 2 *sum(Xyz1_D * (Xyz2_D - Xyz1_D))

       Coeff3 = R2Point1 - rInside2

       Discr = Coeff2**2 - 4 * Coeff1 * Coeff3

       if(Discr < 0.0)then
          write(*,*)'Warning: Discr=',Discr
          !   call SC_stop_mpi("Negative discriminant")
          RETURN
       end if

       ! Find the two intersections (distance from point1 towards point2)
       Discr = sqrt(Discr)
       Solution1 = (-Coeff2 - Discr)/(2 * Coeff1)
       Solution2 = (-Coeff2 + Discr)/(2 * Coeff1)

       Solution1_D = Xyz1_D + (Xyz2_D - Xyz1_D) * Solution1
       Solution2_D = Xyz1_D + (Xyz2_D - Xyz1_D) * Solution2


       ! Check if the solutions are within the segment
       IsGoodSolution1 = (Solution1 >= 0.0 .and. Solution1 <= 1.0)
       IsGoodSolution2 = (Solution2 >= 0.0 .and. Solution2 <= 1.0)

       ! For inner sphere replace 
       ! internal point1 with solution2 and 
       ! internal point2 with solution1
       if(R2Point1 < rInside2) Xyz1_D = Solution2_D
       if(R2Point2 < rInside2) Xyz2_D = Solution1_D

       ! Weird case: the segment cuts the inner sphere
       if(IsGoodSolution1 .and. IsGoodSolution2)then
          ! Need to do two integrals:
          ! from point1 to solution1 and
          ! from point2 to solution2
          if(Discr > 0.0)then
             if(Solution1>cTiny) &
                  call integrate_segment(Xyz1_D, Solution1_D)
             if(solution2 < 1.0-cTiny) &
                  call integrate_segment(Xyz2_D, Solution2_D)
             RETURN
          end if
       end if

    end if

    call integrate_segment(Xyz1_D, Xyz2_D)

  end subroutine los_cut_rmin

  !==========================================================================

  subroutine los_cut_rmax(Xyz1_D, Xyz2_D, rInside, rOutside)

    !Input parameters: coordinates for two points of intersection of
    !the given LOS with the block boundary
    real, dimension(3), intent(inOut) :: Xyz1_D, Xyz2_D

    !The cutoff radius
    real, intent(in) :: rInside, rOutside

    real :: R2Point1, R2Point2,rLine_D(3),rLine2
    real :: Coeff1, Coeff2,Coeff3
    real :: Discr
    real :: Solution1, Solution1_D(3), Solution2, Solution2_D(3)
    logical :: IsOuter, IsGoodSolution1, IsGoodSolution2

    real :: rOutside2
    !------------------------------------------

    rOutside2 = rOutside**2

    R2Point1 = sum(Xyz1_D**2)
    R2Point2 = sum(Xyz2_D**2)

    ! Check if the whole segment is outside rOutside
    rLine_D = XyzPix_D - LosPix_D * sum(LosPix_D * XyzPix_D)
    rLine2  = sum(rLine_D**2)

    if( rLine2 > rOutside2 ) RETURN

    ! Check if there is a need to calculate an intersection

    ! Do we intersect the outer sphere
    IsOuter = R2Point1 > rOutside2 .or. R2Point2 > rOutside2

    ! Do we intersect the inner or outer spheres
    if( IsOuter ) then

       Coeff1 = sum((Xyz2_D - Xyz1_D)**2)
       Coeff2 = 2 * sum(Xyz1_D *( Xyz2_D - Xyz1_D))

       Coeff3 = R2Point1 - rOutside2

       Discr = Coeff2**2 - 4 * Coeff1 * Coeff3

       if(Discr < 0.0)then
          write(*,*)'Warning: Discr=',Discr
          return
       end if

       ! Line of sight tangent to the outer sphere
       if( Discr==0.0 )return

       ! Find the two intersections (distance from point1 towards point2)
       Discr = sqrt(Discr)
       Solution1 = (-Coeff2 - Discr) / (2.0 * coeff1)
       Solution2 = (-Coeff2 + Discr) / (2.0 * coeff1)

       Solution1_D = Xyz1_D + (Xyz2_D - Xyz1_D) * Solution1
       Solution2_D = Xyz1_D + (Xyz2_D - Xyz1_D) * Solution2


       ! Check if the solutions are within the segment
       IsGoodSolution1 = (Solution1 >= 0.0 .and. Solution1 <= 1.0)
       IsGoodSolution2 = (Solution2 >= 0.0 .and. Solution2 <= 1.0)

       ! For outer sphere replace
       ! outlying point1 with solution1 and
       ! outlying point2 with solution2
       if(R2Point1 > rOutside2) then
          if(IsGoodSolution1)then
             Xyz1_D = Solution1_D
          else
             RETURN
          end if
       end if
       if(R2Point2 > rOutside2) then
          if(IsGoodSolution2)then
             Xyz2_D = Solution2_D
          else
             RETURN
          end if
       end if
    end if

    call los_cut_rmin(Xyz1_D, Xyz2_D,rInside)

  end subroutine los_cut_rmax

  !==========================================================================

end subroutine write_plot_los

!==============================================================================

subroutine get_TEC_los_variables(iFile,nPlotVar,plotvarnames,unitstr_TEC)

  use ModPhysics, ONLY : NameTecUnit_V, UnitX_, UnitU_
  use ModIO, ONLY: plot_dimensional
  implicit none

  ! Arguments

  integer, intent(in) :: NPlotVar,iFile
  character (len=20), intent(in) :: plotvarnames(NPlotVar)
  character (len=500), intent(out) :: unitstr_TEC 
  character (len=20) :: s

  integer :: iVar
  !--------------------------------------------------------------------------

  !\
  ! This routine takes the plot_var information and loads the header file with
  ! the appropriate string of variable names and units
  !/

  if (plot_dimensional(ifile)) then
     write(unitstr_TEC,'(a)') 'VARIABLES = '
     write(unitstr_TEC,'(a)') trim(unitstr_TEC)//'"X '//&
          trim(NameTecUnit_V(UnitX_))
     write(unitstr_TEC,'(a)') trim(unitstr_TEC)//'", "Y '//&
          trim(NameTecUnit_V(UnitX_))
  else
     write(unitstr_TEC,'(a)') 'VARIABLES = "X", "Y'
  end if

  do iVar = 1, nPlotVar

     write(unitstr_TEC,'(a)') trim(unitstr_TEC)//'", "'

     s=plotvarnames(iVar)

     if (plot_dimensional(ifile)) then

        select case(s)
        case ('len')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'len'//' '//&
                trim(NameTecUnit_V(UnitX_))
        case('rho')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'`r [m^-^2]'
        case('vlos','Vlos','ulos','Ulos')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'u.s'//' '//&
                trim(NameTecUnit_V(UnitU_))
        case('wl')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'`wl [m^-^2]'//' '
        case('pb')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'`pb [m^-^2]'//' '
        case('euv171')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'`euv171 [DN/S]'//' '
        case('euv195')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'`euv195 [DN/S]'//' '
        case('euv284')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'`euv284 [DN/S]'//' '
        case('sxr')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'`sxr [DN/S]'//' '

           ! DEFAULT FOR A BAD SELECTION
        case default
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'Default'

        end select

     else

        select case(s)
        case ('len')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'len'
        case('rho')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'`r'
        case('vlos','Vlos','ulos','Ulos')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'u.s'
        case('wl')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'wl'
        case('pb')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'pb'
        case('euv171')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'euv171'
        case('euv195')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'euv195'
        case('euv284')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'euv284'
        case('sxr')
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'sxr'

           ! DEFAULT FOR A BAD SELECTION
        case default
           write(unitstr_TEC,'(a)') & 
                trim(unitstr_TEC)//'Default'

        end select

     end if

  end do

  write(unitstr_TEC,'(a)') trim(unitstr_TEC)//'"'

end subroutine get_TEC_los_variables

!==============================================================================
subroutine get_IDL_los_units(ifile,nPlotVar,plotvarnames,unitstr_IDL, UnitForAllnVars)

  use ModPhysics, ONLY : NameIdlUnit_V, UnitX_, UnitU_
  use ModIO, ONLY : plot_dimensional

  implicit none

  ! Arguments

  integer, intent(in) :: iFile,NPlotVar
  logical, intent(in) :: UnitForALlNvars
  character (len=20), intent(in) :: plotvarnames(NPlotVar)
  character (len=79), intent(out) :: unitstr_IDL 
  character (len=20) :: s

  integer :: iVar
  !----------------------------------------------------------------------------

  !\
  ! This routine takes the plot_var information and loads the header file with
  ! the appropriate string of unit values
  !/

  if (plot_dimensional(ifile)) then
     write(unitstr_IDL,'(a)') trim(NameIdlUnit_V(UnitX_))//' '//&
          trim(NameIdlUnit_V(UnitX_))//' '//&
          trim(NameIdlUnit_V(UnitX_))
  else
    if (UnitForAllnVars) then
        do iVar = 1, nPlotVar
           write(unitstr_IDL,'(a)') trim(unitstr_IDL)//' '//'normalized'
 
        end do
        unitstr_IDL=adJustl(trim(unitstr_IDL))
    else
         write(unitstr_IDL,'(a)') 'normalized variables'
    end if

  end if

  if (plot_dimensional(ifile)) then

     do iVar = 1, nPlotVar

        s=plotvarnames(iVar)

        select case(s)
        case ('len')
           write(unitstr_IDL,'(a)') & 
                trim(unitstr_IDL)//' '//&
                trim(NameIdlUnit_V(UnitX_))
        case('rho')
           write(unitstr_IDL,'(a)') & 
                trim(unitstr_IDL)//' '//'[m^-^2]'
        case('vlos','Vlos','ulos','Ulos')
           write(unitstr_IDL,'(a)') & 
                trim(unitstr_IDL)//' '//&
                trim(NameIdlUnit_V(UnitU_))
        case('wl')
           write(unitstr_IDL,'(a)') & 
                trim(unitstr_IDL)//' '//'[m^-^2]'
        case('pb')
           write(unitstr_IDL,'(a)') & 
                trim(unitstr_IDL)//' '//'[m^-^2]'
        case('euv171')
           write(unitstr_IDL,'(a)') & 
                trim(unitstr_IDL)//' '//'euv171 [DN/S]'
        case('euv195')
           write(unitstr_IDL,'(a)') & 
                trim(unitstr_IDL)//' '//'euv195 [dn/s]'
        case('euv284')
           write(unitstr_IDL,'(a)') & 
                trim(unitstr_IDL)//' '//'euv284 [DN/S]'
        case('sxr')
           write(unitstr_IDL,'(a)') & 
                trim(unitstr_IDL)//' '//'sxr [DN/S]'
           ! DEFAULT FOR A BAD SELECTION
        case default
           write(unitstr_IDL,'(a)') & 
                trim(unitstr_IDL)//'" Dflt"'
        end select

     end do

  end if

end subroutine get_IDL_los_units
!==============================================================================
