!  Copyright (C) 2002 Regents of the University of Michigan, 
!  portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
!==============================================================================
module ModGroundMagPerturb

  use ModPlanetConst,    ONLY: rPlanet_I, Earth_
  use ModPhysics,        ONLY: rCurrents, No2Io_V, Si2No_V, UnitB_, UnitJ_
  use ModCoordTransform, ONLY: sph_to_xyz, rot_xyz_sph, cross_product
  use ModConst,          ONLY: cHalfPi, cDegToRad

  implicit none
  save

  private ! except

  public:: read_mag_input_file
  public:: open_magnetometer_output_file
  public:: finalize_magnetometer
  public:: write_magnetometers
  public:: ground_mag_perturb
  public:: ground_mag_perturb_fac

  ! These are not always set this way in ModSize
  integer, parameter:: r_=1, phi_=2, theta_=3

  logical,            public:: save_magnetometer_data = .false.
  integer,            public:: nMagnetometer=0
  character(len=100), public:: MagInputFile
  character(len=7),   public:: TypeMagFileOut='single '

  ! Array for IE Hall & Pederson contribution (3 x 2 x nMags)
  real, allocatable,  public:: IeMagPerturb_DII(:,:,:) 

  !local variables
  integer, parameter :: MaxMagnetometer = 500
  integer            :: iUnitMag = -1
  real               :: PosMagnetometer_II(2,MaxMagnetometer)
  character(len=3)   :: MagName_I(MaxMagnetometer), TypeCoordMagIn='MAG'

contains

  !===========================================================================
  subroutine ground_mag_perturb(nMag, Xyz_DI, MagPerturb_DI)

    ! This subroutine is used to calculate the 3D ground magnetic perturbations, 
    ! at a given set of points (Xyz_DI) for nMag different magnetometers,
    ! from currents in GM cells.  The result is returned as MagPerturb_DI.

    use ModSize,           ONLY: nI, nJ, nK, nBLK
    use ModGeometry,       ONLY: R_BLK, x1, x2, y1, y2, z1, z2
    use ModMain,           ONLY: x_, y_, z_, &
         Unused_B, nBlock, Time_Simulation, TypeCoordSystem
    use ModNumConst,       ONLY: cPi
    use ModCurrent,        ONLY: get_current
    use CON_axes,          ONLY: transform_matrix
    use BATL_lib,          ONLY: MinI, MaxI, MinJ, MaxJ, MinK, MaxK, Xyz_DGB

    integer, intent(in)                    :: nMag
    real,    intent(in), dimension(3,nMag) :: Xyz_DI
    real,    intent(out),dimension(3,nMag) :: MagPerturb_DI
    integer  :: i,j,k,iBLK,iMag
    real     :: r3, XyzSph_DD(3,3), GmtoSmg_DD(3,3)
    real, dimension(3):: Xyz_D, Temp_D, Current_D, MagPerturb_D, TmpSph_D
    real, external    :: integrate_BLK
    real, allocatable, dimension(:,:,:,:) :: Temp_BLK_x,Temp_BLK_y,Temp_BLK_z

    !--------------------------------------------------------------------

    if(.not.allocated(Temp_BLK_x))&
         allocate(Temp_BLK_x(MinI:MaxI,MinJ:MaxJ,MinK:MaxK,nBLK), &
         Temp_BLK_y(MinI:MaxI,MinJ:MaxJ,MinK:MaxK,nBLK), &
         temp_BLK_z(MinI:MaxI,MinJ:MaxJ,MinK:MaxK,nBLK))

    Temp_BLK_x = 0.0
    Temp_BLK_y = 0.0
    Temp_BLK_z = 0.0
    !\
    ! Calculate the magnetic perturbations in cartesian coordinates
    !/

    GmtoSmg_DD = transform_matrix(Time_Simulation, TypeCoordSystem, 'SMG')

    do iMag = 1, nMag
       Xyz_D = Xyz_DI(:,iMag)

       do iBLK=1, nBlock
          if (Unused_B(iBLK))cycle
          do k=1, nK; do j=1, nJ; do i=1, nI
             if ( r_BLK(i,j,k,iBLK) < rCurrents .or. &
                  Xyz_DGB(x_,i+1,j,k,iBLK) > x2 .or.      &
                  Xyz_DGB(x_,i-1,j,k,iBLK) < x1 .or.      &
                  Xyz_DGB(y_,i,j+1,k,iBLK) > y2 .or.      &
                  Xyz_DGB(y_,i,j-1,k,iBLK) < y1 .or.      &
                  Xyz_DGB(z_,i,j,k+1,iBLK) > z2 .or.      &
                  Xyz_DGB(z_,i,j,k-1,iBLK) < z1 ) then
                Temp_BLK_x(i,j,k,iBLK)=0.0
                Temp_BLK_y(i,j,k,iBLK)=0.0
                Temp_BLK_z(i,j,k,iBLK)=0.0
                CYCLE
             end if

             call get_current(i,j,k,iBLK,Current_D)

             r3 = (sqrt(sum((Xyz_D-Xyz_DGB(:,i,j,k,iBLK))**2)))**3

             Temp_D = cross_product(Current_D, Xyz_D-Xyz_DGB(:,i,j,k,iBLK))/r3 

             Temp_BLK_x(i,j,k,iBLK) = Temp_D(1)
             Temp_BLK_y(i,j,k,iBLK) = Temp_D(2)
             Temp_BLK_z(i,j,k,iBLK) = Temp_D(3)
          end do; end do; end do
       end do

       MagPerturb_DI(x_,iMag) = Integrate_BLK(1,Temp_BLK_x)/(4*cPi) 
       MagPerturb_DI(y_,iMag) = Integrate_BLK(1,Temp_BLK_y)/(4*cPi)
       MagPerturb_DI(z_,iMag) = Integrate_BLK(1,Temp_BLK_z)/(4*cPi)

       ! Convert to SMG coordinates
       MagPerturb_D = matmul(GmtoSmg_DD, MagPerturb_DI(:,iMag))

       ! Transform to spherical coordinates (r,theta,phi) components
       Xyz_D = matmul(GmtoSmg_DD, Xyz_DI(:,iMag))

       if (Xyz_D(1) == 0.0 .and. Xyz_D(2) == 0.0 .and. Xyz_D(3) == 0.0) then
          MagPerturb_DI(:,iMag) = MagPerturb_D
       else
          XyzSph_DD = rot_xyz_sph(Xyz_D)
          TmpSph_D = matmul(MagPerturb_D, XyzSph_DD)

          ! Transform to spherical coordinates (north, east, down) components
          MagPerturb_DI(1,iMag)  = -TmpSph_D(phi_) 
          MagPerturb_DI(2,iMag)  =  TmpSph_D(theta_) 
          MagPerturb_DI(3,iMag)  = -TmpSph_D(r_) 
       end if

    end do

    deallocate(Temp_BLK_x,Temp_BLK_y,Temp_BLK_z)
  end subroutine ground_mag_perturb

  !=====================================================================
  subroutine ground_mag_perturb_fac(nMag, Xyz_DI, MagPerturb_DI)
    ! For nMag magnetometers at locations Xyz_DI, calculate the 3-component
    ! pertubation of the magnetic field (returned as MagPerturb_DI) due
    ! to "gap region" field-aligned currents.  These are the FACs taken 
    ! towards the inner boundary of BATS-R-US and mapped to ionospheric
    ! altitudes (sub-MHD locations, the so-called "gap region") along assumed
    ! dipole field lines.

    use ModProcMH,         ONLY: iProc, nProc, iComm
    use ModMain,           ONLY: Time_Simulation
    use CON_planet_field,  ONLY: get_planet_field, map_planet_field
    use ModNumConst,       ONLY: cPi, cTwoPi
    use ModCurrent,        ONLY: calc_field_aligned_current
    use ModMpi

    integer, intent(in)   :: nMag
    real, intent(in)      :: Xyz_DI(3,nMag)
    real, intent(out)     :: MagPerturb_DI(3,nMag)


    real, parameter       :: rIonosphere = 1.01725 ! rEarth + iono_height
    integer, parameter    :: nTheta =181, nPhi =181,nCuts = 800

    integer               :: k, iHemisphere, iError
    integer               :: iTheta,iPhi,iLine,iMag
    real                  :: dR_Trace, Theta, Phi, r_tmp
    real                  :: dL, dS, dTheta, dPhi ,iLat, SinTheta
    real                  :: b, Fac, bRcurrents,JrRcurrents
    real, dimension(3, 3) :: XyzSph_DD
    real, dimension(3)    :: Xyz_D, b_D, bRcurrents_D, XyzRcurrents_D, &
         XyzTmp_D, j_D, temp_D, TmpSph_D
    real                  :: FacRcurrents_II(nTheta,nPhi)
    real                  :: bRcurrents_DII(3,nTheta,nPhi)
    !------------------------------------------------------------------

    MagPerturb_DI= 0.0

    dTheta = cPi    / (nTheta-1)
    dPhi   = cTwoPi / (nPhi-1)
    dR_Trace = (rCurrents - rIonosphere) / nCuts

    ! Get the current and B at the ionosphere boundary
    call calc_field_aligned_current(nTheta,nPhi,rCurrents, &
         FacRcurrents_II, bRcurrents_DII)

    if(nProc>1)then
       call MPI_Bcast(FacRcurrents_II, nTheta*nPhi,MPI_REAL,0,iComm,iError)
       call MPI_Bcast(bRcurrents_DII, 3*nTheta*nPhi,MPI_REAL,0,iComm,iError)
    end if

    ! only need those currents that are above certain threshold
    where(abs(FacRcurrents_II) * No2Io_V(UnitJ_) < 1.0E-4 &
         .or. abs(FacRcurrents_II) * No2Io_V(UnitJ_) >  1.0e3)&
         FacRcurrents_II = 0.0

    iLine=-1
    do iTheta = 1, nTheta
       Theta = (iTheta-1) * dTheta
       if(iTheta==1 .or. iTheta == nTheta)Theta = 1.0E-4
       SinTheta = sin(Theta)          

       do iPhi=1, nPhi
          Phi = (iPhi-1) * dPhi

          ! if the FAC is under certain threshold, do nothing
          if (FacRcurrents_II(iTheta,iPhi) ==0.0)CYCLE

          iLine = iLine +1
          ! do parallel computation among the processors
          if(mod(iLine,nProc) /= iProc)CYCLE

          call sph_to_xyz(rCurrents,Theta,Phi,XyzRcurrents_D)

          ! extract the field aligned current and B field
          JrRcurrents = FacRcurrents_II(iTheta,iPhi)

          bRcurrents_D= bRcurrents_DII(:,iTheta,iPhi)
          bRcurrents = sqrt(sum(bRcurrents_D**2))

          do k=1,nCuts

             r_tmp = rCurrents - dR_Trace * k
             ! get next position along the field line
             call map_planet_field(Time_Simulation,XyzRcurrents_D,'SMG NORM', &
                  r_tmp, XyzTmp_D,iHemisphere)

             ! get the B field at this position
             call get_planet_field(Time_Simulation, XyzTmp_D,'SMG NORM',B_D)
             B_D = B_D *Si2No_V(UnitB_)
             b = sqrt(sum(B_D**2))

             ! get the field alinged current at this position
             Fac = b/bRcurrents * JrRcurrents
             ! get the (x,y,z) components of the Jr
             j_D = Fac * B_D/b

             ! the length of the field line between two cuts
             iLat = abs(asin(XyzTmp_D(3)/sqrt(sum(XyzTmp_D**2))))
             dL = dR_Trace * sqrt(1+3*(sin(iLat))**2)/(2*sin(iLat))
             ! the cross section area by conversation of magnetic flux
             dS = bRcurrents/ b * rCurrents**2 * SinTheta * dTheta *dPhi

             do iMag=1,nMag
                Xyz_D = Xyz_DI(:,iMag)

                if(Xyz_D(3) > 0 .and. Theta > cHalfPi &
                     .or. Xyz_D(3) < 0 .and. Theta < cHalfPi) CYCLE

                ! Do the Biot-Savart integral JxR/|R|^3 dV for all the magnetometers
                temp_D = cross_product(j_D, Xyz_D-XyzTmp_D) & 
                     * dL * dS /(sqrt(sum((XyzTmp_D-Xyz_D)**2)))**3

                MagPerturb_DI(:,iMag)=MagPerturb_DI(:,iMag)+temp_D/(4*cPi)
             end do

          end do
       end do
    end do

    do iMag=1, nMag
       if (Xyz_DI(1,iMag) == 0.0 .and. Xyz_DI(2,iMag) == 0.0 &
            .and. Xyz_DI(3,iMag) == 0.0) then 
       else
          ! Transform to spherical coordinates (r,theta,phi) components
          XyzSph_DD = rot_xyz_sph(Xyz_DI(:,iMag))
          TmpSph_D = matmul(MagPerturb_DI(:,iMag), XyzSph_DD)

          ! Transform to spherical coordinates (north, east, down) components
          MagPerturb_DI(1,iMag)  = -TmpSph_D(phi_) 
          MagPerturb_DI(2,iMag)  =  TmpSph_D(theta_) 
          MagPerturb_DI(3,iMag)  = -TmpSph_D(r_) 
       end if

    end do

  end subroutine ground_mag_perturb_fac
  !================================================================
  subroutine read_mag_input_file
    ! Read the magnetometer input file which governs the number of virtual
    ! magnetometers to be used and their location and coordinate systems.
    ! Input values read from file are saved in module-level variables.

    use ModProcMH, ONLY: iProc, iComm
    use ModMain, ONLY: lVerbose
    use ModIO, ONLY: FileName, Unit_Tmp, iUnitOut, Write_prefix

    use ModMpi

    integer :: iError, nStat

    ! One line of input
    character (len=100) :: Line
    character(len=3) :: iMagName
    real             :: iMagmLat, iMagmLon
    real, dimension(MaxMagnetometer)      :: MagmLat_I, MagmLon_I

    integer          :: iMag
    character(len=*), parameter :: NameSub = 'read_magnetometer_input_files'
    logical          :: DoTest, DoTestMe
    !---------------------------------------------------------------------

    call set_oktest(NameSub, DoTest, DoTestMe)

    ! Read file on the root processor
    if (iProc == 0) then

       filename = MagInputFile    

       if(lVerbose>0)then
          call write_prefix; write(iUnitOut,*) NameSub, &
               " reading: ",trim(filename)
       end if

       open(unit_tmp, file=filename, status="old", iostat = iError)
       if (iError /= 0) call stop_mpi(NameSub // &
            ' ERROR: unable to open file ' // trim(filename))

       nStat = 0

       ! Read the file: read #COORD TypeCoord, #START 
       READFILE: do

          read(unit_tmp,'(a)', iostat = iError ) Line

          if (iError /= 0) EXIT READFILE

          if(index(Line,'#COORD')>0) then
             read(unit_tmp,'(a)') TypeCoordMagIn
             select case(TypeCoordMagIn)
             case('MAG','GEO','SMG')
                call write_prefix;
                write(iUnitOut,'(a)') 'Magnetometer Coordinates='//TypeCoordMagIn
             case default
                call stop_mpi(NameSub//' invalid TypeCoordMagIn='//TypeCoordMagIn)
             end select
          endif

          if(index(Line,'#START')>0)then
             READPOINTS: do
                read(unit_tmp,*, iostat=iError) iMagName, iMagmLat, iMagmLon
                if (iError /= 0) EXIT READFILE

                if (nStat >= MaxMagnetometer) then
                   call write_prefix;
                   write(*,*) NameSub,' WARNING: magnetometers file: ',&
                        trim(filename),' contains too many stations! '
                   call write_prefix; write(*,*) NameSub, &
                        ': max number of stations =',MaxMagnetometer
                   EXIT READFILE
                endif

                !Add new points
                nStat = nStat + 1

                !Store the locations and name of the stations
                MagmLat_I(nStat)    = iMagmLat
                MagmLon_I(nStat)    = iMagmLon
                MagName_I(nStat)    = iMagName

             end do READPOINTS

          end if

       end do READFILE

       close(unit_tmp)

       if(DoTest)write(*,*) NameSub,': nstat=',nStat

       ! Number of magnetometers 
       nMagnetometer = nStat
       write(*,*) NameSub, ': Number of Magnetometers: ', nMagnetometer
       if (nMagnetometer==0.0) call CON_stop(NameSub // &
            ' No magnetometers found in input file!')

       ! Save the positions (maglatitude, maglongitude)
       do iMag=1, nMagnetometer
          PosMagnetometer_II(1,iMag) = MagmLat_I(iMag)
          PosMagnetometer_II(2,iMag) = MagmLon_I(iMag)
       end do

    end if

    ! Tell the coordinates to the other processors
    call MPI_Bcast(TypeCoordMagIn, 3, MPI_CHARACTER, 0, iComm, iError)
    ! Tell the number of magnetometers to the other processors
    call MPI_Bcast(nMagnetometer, 1, MPI_INTEGER, 0, iComm, iError)
    ! Tell the magnetometer name to the other processors
    call MPI_Bcast(MagName_I, nMagnetometer*3, MPI_CHARACTER,0,iComm,iError)
    ! Tell the other processors the coordinates
    call MPI_Bcast(PosMagnetometer_II, 2*nMagnetometer, MPI_REAL, 0, &
         iComm, iError)

    ! Allocate IE array using nMagnetometer, initialize to zero.
    allocate(IeMagPerturb_DII(3,2,nMagnetometer))
    IeMagPerturb_DII = 0.0

  end subroutine read_mag_input_file

  !===========================================================================
  subroutine open_magnetometer_output_file
    ! Open and initialize the magnetometer output file.  A new IO logical unit
    ! is created and saved for future writes to this file.

    use ModMain,   ONLY: n_step
    use ModIoUnit, ONLY: io_unit_new
    use ModIO,     ONLY: NamePlotDir, IsLogName_e

    character(len=100):: NameFile
    integer :: iMag, iTime_I(7)
    logical :: oktest, oktest_me
    !------------------------------------------------------------------------
    ! Open the output file 
    call set_oktest('open_magnetometer_output_files', oktest, oktest_me)

    ! If writing new files every time, no initialization needed.
    if(TypeMagFileOut /= 'single')return

    if(IsLogName_e)then
       ! Event date added to magnetic perturbation file name
       call get_date_time(iTime_I)
       write(NameFile, '(a, a, i4.4, 2i2.2, "-", 3i2.2, a)') &
            trim(NamePlotDir), 'magnetometers_e', iTime_I(1:6), '.mag'
    else
       write(NameFile,'(a,a, i8.8, a)') &
            trim(NamePlotDir), 'magnetometers_n', n_step, '.mag'
    end if
    if(oktest) then
       write(*,*) 'open_magnetometer_output_files: NameFile:', NameFile
    end if

    iUnitMag= io_unit_new()
    open(iUnitMag, file=NameFile, status="replace")

    ! Write the header
    write(iUnitMag, '(i5,a)',ADVANCE="NO") nMagnetometer, ' magnetometers:'
    do iMag=1,nMagnetometer-1 
       write(iUnitMag, '(1X,a)', ADVANCE='NO') MagName_I(iMag)
    end do
    write(iUnitMag, '(1X,a)') MagName_I(nMagnetometer)
    write(iUnitMag, '(a)')  &
         'nstep year mo dy hr mn sc msc station X Y Z '// &
         'dBn dBe dBd dBnMhd dBeMhd dBdMhd dBnFac dBeFac dBdFac ' // &
         'dBnHal dBeHal dBdHal dBnPed dBePed dBdPed'

  end subroutine open_magnetometer_output_file

  !=====================================================================
  subroutine write_magnetometers
    ! Write ground magnetometer field perturbations to file.  Values, IO units,
    ! and other information is gathered from module level variables.

    use ModProcMH,ONLY: iProc, nProc, iComm
    use CON_axes, ONLY: transform_matrix
    use ModMain,  ONLY: n_step, time_simulation,&
         TypeCoordSystem
    use ModUtilities, ONLY: flush_unit
    use ModMpi

    integer           :: iMag, iError
    !year,month,day,hour,minute,second,msecond
    real, dimension(3):: Xyz_D
    real, dimension(3,nMagnetometer):: MagPerturbGmSph_DI, MagPerturbFacSph_DI,&
         MagGmXyz_DI, MagSmXyz_DI, MagVarSum_DI, MagVarFac_DI, &
         MagVarGm_DI, MagVarTotal_DI
    real:: MagtoGm_DD(3,3), GmtoSm_DD(3,3)

    character(len=*), parameter :: NameSub = 'write_magnetometers'
    logical                     :: DoTest, DoTestMe
    !---------------------------------------------------------------------

    call set_oktest(NameSub, DoTest, DoTestMe)

    ! Matrix between two coordinates
    MagtoGm_DD = transform_matrix(Time_Simulation, &
         TypeCoordMagIn, TypeCoordSystem)
    GmtoSm_DD = transform_matrix(Time_Simulation, TypeCoordSystem, 'SMG')

    !\
    ! Transform the Radius position into cartesian coordinates. 
    ! Transform the magnetometer position from MagInCorrd to GM/SM
    !/

    do iMag=1,nMagnetometer
       ! (360,360) is for the station at the center of the planet
       if ( nint(PosMagnetometer_II(1,iMag)) == 360 .and. &
            nint(PosMagnetometer_II(2,iMag)) == 360) then 
          Xyz_D = 0.0
       else 
          call  sph_to_xyz(1.0,                           &
               (90-PosMagnetometer_II(1,iMag))*cDegToRad, &
               PosMagnetometer_II(2,iMag)*cDegToRad,      &
               Xyz_D)
          Xyz_D = matmul(MagtoGm_DD, Xyz_D)
       end if

       MagGmXyz_DI(:,iMag) = Xyz_D
       MagSmXyz_DI(:,iMag) = matmul(GmtoSm_DD, Xyz_D)
    end do

    !-------------------------------------------------------------------
    ! Calculate the perturbations from GM currents and FACs in the Gap Region;
    ! The results are in SM spherical coordinates.
    !------------------------------------------------------------------
    call ground_mag_perturb(    nMagnetometer, &
         MagGmXyz_DI, MagPerturbGmSph_DI) 

    call ground_mag_perturb_fac(nMagnetometer, &
         MagSmXyz_DI, MagPerturbFacSph_DI)

    !\
    ! Collect the variables from all the PEs
    !/
    MagVarSum_DI = 0.0
    if(nProc>1)then 
       call MPI_reduce(MagPerturbGmSph_DI, MagVarSum_DI, 3*nMagnetometer, &
            MPI_REAL, MPI_SUM, 0, iComm, iError)
       if(iProc==0)MagPerturbGmSph_DI = MagVarSum_DI

       call MPI_reduce(MagPerturbFacSph_DI, MagVarSum_DI, 3*nMagnetometer, &
            MPI_REAL, MPI_SUM, 0, iComm, iError)
       if(iProc==0)MagPerturbFacSph_DI = MagVarSum_DI
    end if

    ! Collect variables, send to appropriate write subroutine.
    if(iProc==0)then      
       do iMag=1,nMagnetometer
          !normalize the variable to I/O unit:
          MagVarGm_DI( :,iMag)  = MagPerturbGMSph_DI( :,iMag) * No2Io_V(UnitB_)
          MagVarFac_DI( :,iMag) = MagPerturbFacSph_DI(:,iMag) * No2Io_V(UnitB_)

          ! Get total perturbation:
          MagVarTotal_DI( :,iMag) = MagVarGm_DI( :,iMag)+MagVarFac_DI( :,iMag)+&
               IeMagPerturb_DII(:,1,iMag) + IeMagPerturb_DII(:,2,iMag)
       end do

       select case(TypeMagFileOut)
          case('single')
             call write_mag_single
          case('step')
             call write_mag_step
          case('station')
             call CON_stop(NameSub//': separate mag files not implemented yet.')
       end select

    end if

  contains
    !=====================================================================
    subroutine write_mag_single
      ! For TypeMagFileOut == 'single', write a single record to the file.

      integer :: iTime_I(7)
      !--------------------------------------------------------------------
      ! Get current time.
      call get_date_time(iTime_I)

      ! Write data to file.
      do iMag=1, nMagnetometer
         ! Write time and magnetometer number to file:
         write(iUnitMag,'(i8)',ADVANCE='NO') n_step
         write(iUnitMag,'(i5,5(1X,i2.2),1X,i3.3)',ADVANCE='NO') iTime_I
         write(iUnitMag,'(1X,i4)', ADVANCE='NO')  iMag

         ! Write position of magnetometer and perturbation to file:  
         write(iUnitMag,'(18es13.5)') &
              MagSmXyz_DI(:,iMag)*rPlanet_I(Earth_), &
              MagVarTotal_DI(:,iMag), MagVarGm_DI(:,iMag), &
              MagVarFac_DI(:,iMag), IeMagPerturb_DII(:,1,iMag), &
              IeMagPerturb_DII(:,2,iMag)
      end do

      ! Flush file buffer.
      call flush_unit(iUnitMag)

    end subroutine write_mag_single

    !=====================================================================
    subroutine write_mag_step
      ! For TypeMagFileOut == 'step', write one file for every write step.
      use ModIoUnit, ONLY: UnitTmp_
      use ModIO,     ONLY: NamePlotDir, IsLogName_e

      integer ::  iTime_I(7)

      character(len=100):: NameFile
      !------------------------------------------------------------------------
      call get_date_time(iTime_I)
      if(IsLogName_e)then
         ! Event date added to magnetic perturbation file name
         write(NameFile, '(a, a, i4.4, 2i2.2, "-", 3i2.2, a)') &
              trim(NamePlotDir), 'magnetometers_e', iTime_I(1:6), '.mag'
      else
         write(NameFile,'(a,a, i8.8, a)') &
              trim(NamePlotDir), 'magnetometers_n', n_step, '.mag'
      end if

      ! Open file for output:
      open(UnitTmp_, file=NameFile, status="replace")

      ! Write the header
      write(UnitTmp_, '(i5,a)',ADVANCE="NO") nMagnetometer, ' magnetometers:'
      do iMag=1,nMagnetometer-1 
         write(UnitTmp_, '(1X,a)', ADVANCE='NO') MagName_I(iMag)
      end do
      write(UnitTmp_, '(1X,a)') MagName_I(nMagnetometer)
      write(UnitTmp_, '(a)')  &
           'nstep year mo dy hr mn sc msc station X Y Z '// &
           'dBn dBe dBd dBnMhd dBeMhd dBdMhd dBnFac dBeFac dBdFac ' // &
           'dBnHal dBeHal dBdHal dBnPed dBePed dBdPed'

      ! Write data to file.
      do iMag=1, nMagnetometer
         ! Write time and magnetometer number to file:
         write(UnitTmp_,'(i8)',ADVANCE='NO') n_step
         write(UnitTmp_,'(i5,5(1X,i2.2),1X,i3.3)',ADVANCE='NO') iTime_I
         write(UnitTmp_,'(1X,i4)', ADVANCE='NO')  iMag

         ! Write position of magnetometer and perturbation to file:  
         write(UnitTmp_,'(18es13.5)') &
              MagSmXyz_DI(:,iMag)*rPlanet_I(Earth_), &
              MagVarTotal_DI(:,iMag), MagVarGm_DI(:,iMag), &
              MagVarFac_DI(:,iMag), IeMagPerturb_DII(:,1,iMag), &
              IeMagPerturb_DII(:,2,iMag)
      end do

      ! Close file:
      close(UnitTmp_)

    end subroutine write_mag_step
    !=====================================================================
  end subroutine write_magnetometers

  !=====================================================================
  subroutine finalize_magnetometer
    ! Close the magnetometer output file (flush buffer, release IO unit).

    use ModProcMH, ONLY: iProc

    if(iProc==0 .and. TypeMagFileOut /= 'step') close(iUnitMag)
    if (allocated(IeMagPerturb_DII)) deallocate(IeMagPerturb_DII)

  end subroutine finalize_magnetometer

  !============================================================================

end module ModGroundMagPerturb
