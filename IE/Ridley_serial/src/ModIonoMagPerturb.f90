!  Copyright (C) 2002 Regents of the University of Michigan, 
!  portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
module ModIonoMagPerturb

  use ModCoordTransform, ONLY: sph_to_xyz, xyz_to_sph, cross_product, rot_xyz_sph
  use ModConst, ONLY: cDegToRad, cMu
  use ModProcIE
  use ModIonosphere
  use IE_ModIO
  use IE_ModMain, ONLY: Time_Simulation, time_array, nSolve
  use ModFiles, ONLY: MagInputFile
  implicit none

  save

  public:: read_mag_input_file
  public:: open_iono_magperturb_file
  public:: close_iono_magperturb_file
  public:: write_iono_magperturb_file

  logical, public    :: save_magnetometer_data = .false., &
       Initialized_Mag_File=.false.
  integer            :: nMagnetometer = 0
  integer            :: iUnitMag = -1
  integer, parameter :: MaxMagnetometer = 500
  real, dimension(2,MaxMagnetometer) :: PosMagnetometer_II
  character(len=3)   :: MagName_I(MaxMagnetometer), TypeCoordMagIn


contains
  !======================================================================
  subroutine iono_mag_perturb(nMag, Xyz0_DI, JhMagPerturb_DI, JpMagPerturb_DI)
    ! For a series of nMag virtual observatories at SMG coordinates Xyz0_DI, 
    ! calculate the magnetic pertubation from the ionospheric Pederson currents
    ! (JpMagPerturb_DI) and Hall currents (JhMagPerturb_DI) in three orthogonal
    ! directions.

    use CON_planet_field, ONLY: get_planet_field

    implicit none

    integer,intent(in)                     :: nMag
    real,   intent(in),  dimension(3,nMag) :: Xyz0_DI
    real,   intent(out), dimension(3,nMag) :: JhMagPerturb_DI, JpMagPerturb_DI

    integer, parameter :: nTheta = IONO_nTheta, nPsi = IONO_nPsi

    real, dimension(nTheta*2, nPsi, 3) :: Jh_IID, Jp_IID, Xyz_IID, eIono_IID
    real, dimension(nTheta*2, nPsi)    :: Phi, Theta, Psi, ETh, EPs, &
         SigmaH, SigmaP, SinTheta, SinPhi, CosTheta, CosPhi
    real, dimension(3)                 :: bIono_D,  Xyz0_D, MagJh_D, MagJp_D, &
         XyzIono_D, tempJh_dB, tempJp_dB, TempMagJh_D,TempMagJp_D

    real :: dTheta(nTheta*2),dPsi(nPsi)
    real :: dv
    real :: XyzSph_DD(3,3)
    integer :: i, j, iMag
    !\
    ! calculate the magnetic perturbations at the location of (SMLat, SMLon)
    ! in the SM coordinates, by integrating over the Hall and Perdersen
    ! current systems.
    !/
    JhMagPerturb_DI = 0.0
    JpMagPerturb_DI = 0.0

    Phi(1:nTheta,:)   = Iono_North_PHi
    Theta(1:nTheta,:) = Iono_North_Theta
    Psi(1:nTheta,:)   = Iono_North_Psi
    SigmaH(1:nTheta,:)= Iono_North_SigmaH
    SigmaP(1:nTheta,:)= Iono_North_SigmaP
    dTheta(1:nTheta)  = dTheta_North
    dPsi = dPsi_North

    Phi(nTheta+1:nTheta*2,:)   = Iono_South_PHi
    Theta(nTheta+1:nTheta*2,:) = Iono_South_Theta
    Psi(nTheta+1:nTheta*2,:)   = Iono_South_Psi
    SigmaH(nTheta+1:nTheta*2,:)= Iono_South_SigmaH
    SigmaP(nTheta+1:nTheta*2,:)= Iono_South_SigmaP
    dTheta(nTheta+1:nTheta*2)  = dTheta_South
    dPsi = dPsi_South

    SinTheta = sin(Theta)
    SinPhi   = sin(Psi)
    CosTheta = cos(Theta)
    CosPhi   = cos(Psi)

    ! dTheta at the poles is 1 degree; the rest are 2 degrees.
    ! dPsi is 4 degrees.
    dTheta(2:nTheta*2-1) = dTheta(2:nTheta*2-1)/2.0
    dPsi = dPsi/2.0

    do j = 1, nPsi
       if ( j<nPsi ) then

          do i = 1, nTheta*2-1
             ETh(i,j) = -(PHI(i+1,j)-PHI(i,j))/                     &
                  (dTheta(i)*Radius)
             EPs(i,j) = -(PHI(i,j+1)-PHI(i,j))/                     &
                  (dPsi(j)*Radius*SinTheta(i,j))
          end do
          ETh(nTheta*2,j)   = ETh(nTheta*2-1,j)
          EPs(nTheta*2,j)   = EPs(nTheta*2-1,j)

       else 
          do i = 1, nTheta*2 -1
             ETh(i,j) = -(PHI(i+1,j)-PHI(i,j))/                     &
                  (dTheta(i)*Radius)
             EPs(i,j) = -(PHI(i,1)-PHI(i,j))/                       &
                  (dPsi(j)*Radius*SinTheta(i,j))
          end do

          ETh(nTheta*2,j)   = ETh(nTheta*2-1,j)
          EPs(nTheta*2,j)   = EPs(nTheta*2-1,j)
       end if

    end do

    ! convert to xyz coords
    eIono_IID(:,:,1) =  ETh*CosTheta*CosPhi - EPs*SinPhi
    eIono_IID(:,:,2) =  ETh*CosTheta*SinPhi + EPs*CosPhi
    eIono_IID(:,:,3) = -ETh*SinTheta

    do i = 1, nTheta*2
       do j = 1, nPsi
          call sph_to_xyz(Radius, Theta(i,j), Psi(i,j), XyzIono_D)
          Xyz_IID(i,j,:) = XyzIono_D
          ! get the magnetic field in SMG coords.
          call get_planet_field(Time_simulation, XyzIono_D, 'SMG', bIono_D)
          bIono_D = bIono_D/sqrt(sum(bIono_D**2))

          ! get the Hall and Perdersen currents in xyz coords
          Jh_IID(i,j,:) = cross_product(bIono_D, eIono_IID(i,j,:))*SigmaH(i,j)
          Jp_IID(i,j,:) = eIono_IID(i,j,:) * SigmaP(i,j)
       end do
    end do

    do iMag=1, nMag

       Xyz0_D = Xyz0_DI(:,iMag)

       MagJh_D = 0.0
       MagJp_D = 0.0
       ! Biot-Savart integral to calculate the magnetic perturbations
       if (Xyz0_D(3) < 0) then           
          ! southern hemisphere
          if (iProc /= nProc-1)CYCLE
          do i = nTheta+1, nTheta*2
             do j = 1, nPsi

                tempJh_dB = &
                     cross_product(Jh_IID(i,j,:), Xyz0_D-Xyz_IID(i,j,:)) &
                     / (sqrt( sum( (Xyz_IID(i,j,:)-Xyz0_D)**2 )) )**3

                tempJp_dB = &
                     cross_product(Jp_IID(i,j,:), Xyz0_D-Xyz_IID(i,j,:)) &
                     / (sqrt( sum( (Xyz_IID(i,j,:)-Xyz0_D)**2 )) )**3

                dv = cMu/(4*cPi) * Radius**2 * dTheta(i)*dPsi(j)*SinTheta(i,j)

                MagJh_D = MagJh_D + tempJh_dB * dv
                MagJp_D = MagJp_D + tempJp_dB * dv                

             end do
          end do

       else
          ! northern hemisphere
          if(iProc /= 0)CYCLE
          do i = 1, nTheta
             do j = 1, nPsi

                tempJh_dB = &
                     cross_product(Jh_IID(i,j,:), Xyz0_D-Xyz_IID(i,j,:)) &
                     / (sqrt(sum((Xyz_IID(i,j,:)-Xyz0_D)**2)))**3

                tempJp_dB = &
                     cross_product(Jp_IID(i,j,:), Xyz0_D-Xyz_IID(i,j,:)) &
                     / (sqrt(sum((Xyz_IID(i,j,:)-Xyz0_D)**2)))**3

                dv = cMu/(4*cPi) * Radius**2 * dTheta(i)*dPsi(j)*SinTheta(i,j)

                MagJh_D = MagJh_D + tempJh_dB * dv
                MagJp_D = MagJp_D + tempJp_dB * dv

             end do
          end do
       end if


       ! transform to spherical coords (r, theta, phi)
       XyzSph_DD = rot_xyz_sph(Xyz0_D)

       TempMagJh_D = matmul(MagJh_D,XyzSph_DD)
       TempMagJp_D = matmul(MagJp_D,XyzSph_DD)

       ! convert to (north, east, downward) coordinates in unit of nT
       JhMagPerturb_DI(1,iMag) = -TempMagJh_D(2) * 1.0e9 ! north
       JhMagPerturb_DI(2,iMag) =  TempMagJh_D(3) * 1.0e9 ! east
       JhMagPerturb_DI(3,iMag) = -TempMagJh_D(1) * 1.0e9 ! down

       JpMagPerturb_DI(1,iMag) = -TempMagJp_D(2) * 1.0e9 ! north
       JpMagPerturb_DI(2,iMag) =  TempMagJp_D(3) * 1.0e9 ! east
       JpMagPerturb_DI(3,iMag) = -TempMagJp_D(1) * 1.0e9 ! down

    end do


  end subroutine iono_mag_perturb


  !=====================================================================
  subroutine open_iono_magperturb_file
    ! Open and initialize the magnetometer output file.  A new IO logical unit
    ! is created and saved for future writes to this file.

    use ModIoUnit, ONLY: io_unit_new
    implicit none

    integer :: iMag
    !-----------------------------------------------------------------
    ! Open the output file 
    write(*,*) 'IE: writing magnetic perturbation output.'  
    
    write(NameFile,'(a,3i2.2,"_",3i2.2,a)')trim(NameIonoDir)//"IE_mag_t", &
         mod(time_array(1),100),time_array(2:6), ".mag"

    iUnitMag= io_unit_new()
    open(iUnitMag, file=NameFile)

    ! Write the header
    write(iUnitMag, '(i5,a)', ADVANCE='NO') nMagnetometer, ' magnetometers: '
    do iMag=1, nMagnetometer-1
       write(iUnitMag, '(1x,a)', ADVANCE='NO') MagName_I(iMag) 
    end do
    write(iUnitMag, '(1x,a)')MagName_I(nMagnetometer) 
    write(iUnitMag, '(a)')  &
         'nsolve year mo dy hr mn sc msc station X Y Z '// &
         'JhdBn JhdBe JhdBd JpBn JpBe JpBd'

  end subroutine open_iono_magperturb_file

  !======================================================================
  subroutine get_iono_magperturb_now(PerturbJh_DI, PerturbJp_DI, Xyz_DI)
    ! For all virtual magnetometers, update magnetometer coordinates in SMG 
    ! coordinates. Then, calculate the perturbation from the Hall and Pederson 
    ! currents and return them to caller as PerturbJhOut_DI, PerturbJpOut_DI.
    ! Updated magnetometer coordinates are also returned as Xyz_DI.

    use CON_axes, ONLY: transform_matrix
    use ModMpi

    implicit none

    real, intent(out), dimension(3,nMagnetometer) :: PerturbJh_DI, PerturbJp_DI
    real, intent(out), dimension(3,nMagnetometer) :: Xyz_DI

    real, dimension(3,nMagnetometer):: MagVarSum_Jh_DI, MagVarSum_Jp_DI
    real, dimension(3):: Xyz_D
    real, dimension(3,3) :: MagtoSmg_DD

    integer :: iMag, iError
    !--------------------------------------------------------------------------

    ! Create rotation matrix.
    MagtoSmg_DD = transform_matrix(Time_Simulation, TypeCoordMagIn, 'SMG')

    ! Get current positions of magnetometers in SMG coordinates.
    do iMag = 1 , nMagnetometer
       ! (360,360) is for the station at the center of the planet
       if ( nint(PosMagnetometer_II(1,iMag)) == 360 .and. &
            nint(PosMagnetometer_II(2,iMag)) == 360) then
          Xyz_DI(:,iMag) = 0.0
       else
          call  sph_to_xyz(IONO_Radius, &
               (90-PosMagnetometer_II(1,iMag))*cDegToRad, &
               PosMagnetometer_II(2,iMag)*cDegToRad, Xyz_D)
          Xyz_DI(:,iMag) = matmul(MagtoSmg_DD, Xyz_D)
       end if

    end do

    ! calculate the magnetic perturbation caused by Hall and Perdersen currents
    call iono_mag_perturb(nMagnetometer, Xyz_DI, PerturbJh_DI, PerturbJp_DI)

     !\
     ! Collect the variables from all the PEs
     !/
    MagVarSum_Jh_DI = 0.0
    MagVarSum_Jp_DI = 0.0
    if(nProc > 1)then 
       call MPI_reduce(PerturbJh_DI, MagVarSum_Jh_DI, 3*nMagnetometer, &
            MPI_REAL, MPI_SUM, 0, iComm, iError)
       call MPI_reduce(PerturbJp_DI, MagVarSum_Jp_DI, 3*nMagnetometer, &
            MPI_REAL, MPI_SUM, 0, iComm, iError)
       if(iProc == 0) then
          PerturbJh_DI = MagVarSum_Jh_DI
          PerturbJp_DI = MagVarSum_Jp_DI
       end if
    end if
    
  end subroutine get_iono_magperturb_now
  !======================================================================
  subroutine read_mag_input_file
    ! Read the magnetometer input file which governs the number of virtual
    ! magnetometers to be used and their location and coordinate systems.
    ! Input values read from file are saved in module-level variables.

    use ModMpi

    implicit none

    integer :: iError, nStat

    ! One line of input     
    character (len=100) :: Line
    character(len=3) :: iMagName
    real             :: iMagmLat, iMagmLon
    real, dimension(MaxMagnetometer):: MagmLat_I, MagmLon_I
    integer          :: iMag
    character(len=*), parameter :: NameSub = 'read_magnetometer_input_files'
    logical          :: DoTest, DoTestMe
    !---------------------------------------------------------------------  

    call CON_set_do_test(NameSub, DoTest, DoTestMe)

    ! Read file on the root processor        
    filename = MagInputFile

    call write_prefix; write(*,*) NameSub, &
         " reading: ", trim(filename)

    open(unit=iunit, file=filename, status="old", iostat = iError)
    if (iError /= 0) call CON_stop(NameSub // &
         ' ERROR: unable to open file ' // trim(filename))

    nStat = 0
    ! Read the file: read #COORD TypeCoord, #START
    READFILE: do

       read(iunit,'(a)', iostat = iError ) Line

       if (iError /= 0) EXIT READFILE

       if(index(Line,'#COORD')>0) then
          read(iunit,'(a)') TypeCoordMagIn
          select case(TypeCoordMagIn)
          case('MAG', 'GEO', 'SMG')
             call write_prefix;
             write(*,*) 'Magnetometer Coordinates='//TypeCoordMagIn
          case default
             call CON_stop(NameSub//' invalid TypeCoordMagIn='//TypeCoordMagIn)
          end select
       end if

       if(index(Line,'#START')>0)then
          READPOINTS: do
             read(iunit,*, iostat=iError) iMagName, iMagmLat, iMagmLon
             if (iError /= 0) EXIT READFILE

             !Add new points
             nStat = nStat + 1

             !Store the locations and name of the stations
             MagmLat_I(nStat)    = iMagmLat
             MagmLon_I(nStat)    = iMagmLon
             MagName_I(nStat)    = iMagName

          end do READPOINTS

       end if
    end do READFILE

    close(iunit)

    if(DoTest)write(*,*) NameSub,': nstat=',nStat

    ! Number of magnetometers                    
    nMagnetometer = nStat

    write(*,*) NameSub, ': Number of Magnetometers: ', nMagnetometer

    ! Save the positions (maglatitude, maglongitude)   

    do iMag=1, nMagnetometer
       PosMagnetometer_II(1,iMag) = MagmLat_I(iMag)
       PosMagnetometer_II(2,iMag) = MagmLon_I(iMag)
    end do

  end subroutine read_mag_input_file

  !======================================================================
  subroutine write_iono_magperturb_file
    ! For all virtual magnetometers, calculate the pertubation from the 
    ! Hall and Pedersen currents and write them to file.

    use ModMpi
    use ModUtilities, ONLY: flush_unit
    
    implicit none

    real, dimension(3,nMagnetometer):: MagPerturbJh_DI, MagPerturbJp_DI, Xyz_DI
    integer :: iMag, i
    !---------------------------------------------------------------------

    ! Calculate pertubation on all procs:
    call get_iono_magperturb_now(MagPerturbJh_DI, MagPerturbJp_DI, Xyz_DI)
    
    ! Write file only on iProc=0:
    if(iProc/=0)return

    do iMag = 1, nMagnetometer
       ! writing
       write(iUnitMag,'(i8)',ADVANCE='NO') nSolve
       write(iUnitMag,'(i5,5(1x,i2.2),1x,i3.3)',ADVANCE='NO') &
            (Time_array(i),i=1,7)
       write(iUnitMag,'(1X,i4)', ADVANCE='NO')  iMag
       
       ! Write position of magnetometer in SGM Coords
       write(iUnitMag,'(3es13.5)',ADVANCE='NO') Xyz_DI(:,iMag)
       ! Get the magnetic perturb data and Write out
       write(iUnitMag, '(3es13.5)', ADVANCE='NO') MagPerturbJh_DI(:,iMag)
       ! Write the Jp perturbations
       write(iUnitMag, '(3es13.5)') MagPerturbJp_DI(:,iMag)
       
    end do
    call flush_unit(iUnitMag)

  end subroutine write_iono_magperturb_file

  !=====================================================================
  subroutine close_iono_magperturb_file
    ! Close the magnetometer output file (flush buffer, release IO unit).

    implicit none

    close(iUnit)

  end subroutine close_iono_magperturb_file

  !=====================================================================

end module ModIonoMagPerturb
