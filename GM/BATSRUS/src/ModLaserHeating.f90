!^CFG COPYRIGHT UM
module ModLaserHeating

  ! Calculate heating due to irradiation by a laser. The laser is represented
  ! by a finite number of laser beams. The laser beams are traced through 
  ! the plasa following the rules of geometrical optics. The laser energy is
  ! deposited near the critical density.

  use ModProcMH, ONLY: iProc, nProc, iComm
  use ModAdvance, ONLY: State_VGB
  use ModVarIndexes
  use ModConst
  use ModMpi

  use ModCoordTransform

  use ModPhysics,  ONLY: No2Si_V, Si2No_V, UnitRho_, UnitX_
  use ModMain,     ONLY: TypeBC_I, UseLaserHeating
  use ModGeometry, ONLY: XyzMin_D, XyzMax_D, nDim
  use ModIOUnit,   ONLY: UnitTmp_

  implicit none

  SAVE

  private !Except

  real, public, allocatable:: LaserHeating_CB(:,:,:,:) ! Heating energy density
  public:: read_laser_heating_param  ! Read laser parameters
  public:: add_laser_heating         ! Add heating as pressure/energy source

  ! Local variables

  real, allocatable:: Position_DI(:,:)      ! position of rays
  real, allocatable:: Density_I(:)          ! density*Z at ray position
  real, allocatable:: GradDensity_DI(:,:)   ! gradient of density*Z
  real, allocatable:: EnergyDeposition_I(:) ! energy deposition
  real, allocatable:: DeltaSNew_I(:)        ! step size for rays
  logical, allocatable:: Unused_I(:)        ! true if ray is used


  !Circular frequency, [rad/s]
  real, parameter:: Omega = 3* &            !Third harmonic
       cTwoPi * cLightSpeed/(1.06e-6)       !of the Nd Laser

  !Critical density
  real, parameter:: DensityCrSI  = Omega**2 &
       *cEps * cElectronMass/cElectronCharge**2 *&
       cAtomicMass * 9.0121823              !and for Beryllium

  logical:: DoInit=.true.

  real, allocatable::AbsorptionCoeff_I(:)


  ! the irradiance (power). The pointwise sources of energy calculated by
  ! this subroutine are multipled by :
  ! LaserIrradiance*Si2No_V(UnitEnergydens_)*Si2No_V(UnitX_)**3/Si2No_V(UnitT_)

  logical,dimension(:), pointer:: DoRay_I
  real, allocatable:: Slope_DI(:,:), Intensity_I(:), DeltaS_I(:)
  logical, allocatable:: IsBehindCr_I(:)
  integer:: nRay = -1

  real:: DeltaS = 1.0, Tolerance = 0.1

  logical, parameter:: DoVerbose = .false.

  integer:: iRay

  character(LEN=100)::NameFile

  !The laser pulse is assumed to have the linear raise front
  !and linear decay with the constant irradiance within the
  !pulse,  at  t_raise < t < tPulse - tDecay
  real:: tStart = 0.0     ![s] - allows for nonzero start
  real:: tRaise = 1.0e-10 ![s]
  real:: tDecay = 1.0e-10 ![s]
  real:: tPulse = 1.1e-9  ![s]
  real:: IrradianceSi = 3.8e12 ![J/s] !This is the power; rename?

  !Beam geometry: 'rz', '2d', '3d'
  character(LEN=3):: TypeBeam='unknown'
  !\
  ! Geometry of the 'rz'-beam:
  !/
  !
  !\     |
  !\\    |
  !\\\   |
  ! \\\  |
  !  \\\ |
  !   \\\|
  !    \\|_ _ _ _ _
  !     \|    I
  !      | This height is yCr   
  !______|____V____ axis of symmetry
  !      |
  !      |
  !     /|
  !    //|    In the presented case nRayPerBeam = 1 
  !   ///|    (half of all rays except for the Central Ray (CR))
  !  /// |    The intensity falls as exp(-r^2/rBeam^2),
  ! ///  |    where r is the transverse distance from the CR
  !///   |
  !//slope (approximately +60 deg in the presented case))
  !/-----|
  !
  !< This coordinate is xPlane

  integer:: nRayPerBeam

  integer:: nBeam = 0
  real   :: rBeam = 1.0, xPlane = -60.0

  real   :: BeamParam_II(3,192)

  real   :: SuperGaussianOrder = 4.2

  !Named indexes:
  integer, parameter:: SlopeDeg_ = 1, yCr_ = 2, AmplitudeRel_ = 3

  integer:: nRayTotal = -1
  real, allocatable, dimension(:,:):: XyzRay_DI, SlopeRay_DI 
  real, allocatable, dimension(:)  :: Amplitude_I

  logical :: DoLaserRayTest  = .false.

contains
  !==========================================================================
  subroutine calc_absorption(NAtomicSI, ZAverage, TeSI, RhoSI, Absorption)
    !The subroutine calculates the absorption coefficient, Absorption [m-1],
    ! at the circular frequency, omega and convert then to the dimensionless
    !form

    real,intent(in):: NAtomicSI, ZAverage, TeSI, RhoSI
    real, intent(out):: Absorption  !The absorption coefficient, [m-1]

    real:: AveragedElectronSpeed, CollisionCrossSection
    real:: EffectiveCollisionRate, Dens2DensCr
    real,parameter::CoulombLog = 5.0
    !------------------------------------------------------------------------

    Dens2DensCr = min(1.0, RhoSI/DensityCrSi)
    !calculate the effective collision frequency
    !write(*,*)'RhoSi=',RhoSi,' Dens2DensCr=',Dens2DensCr

    if(DoLaserRayTest)then

       ! Set EffectiveCollisionRate proportional to the density. Kruer p. 51
       ! assumes EffectiveCollisionRate at the critical density / omega << 1.0
       EffectiveCollisionRate = 2.0e+12*Dens2DensCr
    else

       AveragedElectronSpeed = sqrt(8.0*cBoltzmann &
            *TeSi/(cPi*cElectronMass))
       !write(*,*)'TeSi=',TeSi,' AverageElectronSpeed=',AveragedElectronSpeed
       CollisionCrossSection = cPi*2.0/3.0 &
            *(cElectronCharge**2/(4.0*cPi*cEps*(cBoltzmann*TeSi)))**2
       !write(*,*)'Collision Cross Section =', CollisionCrossSection
       EffectiveCollisionRate = CollisionCrossSection* &
            (NatomicSi*ZAverage**2)*AveragedElectronSpeed*CoulombLog 
       !write(*,*)'NAtomicSi=',NAtomicSi, &
       !          ' EffectiveCollisionRate=',EffectiveCollisionRate

    end if

    Absorption = EffectiveCollisionRate/cLightSpeed*Dens2DensCr/&
         sqrt(1 - Dens2DensCr/(1 + (EffectiveCollisionRate/Omega)**2) )
    !write(*,*)'Dimensional absorption=', Absorption
    !Convert to the dimensionless form:
    Absorption =  Absorption*No2Si_V(UnitX_)

  end subroutine calc_absorption

  !============================================================================

  subroutine get_density_and_absorption(nRay)

    ! Calculates plasma density, Density_I, and its gradient, 
    ! GradDensity_DI(3,nRay), at specified locations Position_DI(3,nRay)
    ! Also, it provides appropriate step, DeltaSNew_I, conceivably dependent
    ! on the numeric grid size

    use ModProcMH, ONLY: iProc, nProc, iComm
    use ModPhysics, ONLY:No2Si_V, UnitRho_
    use BATL_lib, ONLY: nDim, MaxDim, CellSize_DB, interpolate_grid
    use ModUser, ONLY: user_material_properties

    integer,intent(in)::nRay

    integer:: iRay, iBlock, iCell, nCell
    integer:: iCell_II(0:nDim,2**nDim), iCell_D(MaxDim), i, j, k

    real:: Weight_I(2**nDim), Weight
    real:: NatomicSi, TeSI, Zaverage, RhoZSi, Absorption
    real:: ZaverageL, ZaverageR

    ! Variables interpolated to ray positions
    integer, parameter:: GradXRhoZ_=1, GradYRhoZ_=2, GradZRhoZ_=3, RhoZ_=4, &
         Absorption_=5, CellSize_=6, nVarRay = CellSize_
    real, allocatable:: RayValue_VI(:,:), RayValueAll_VI(:,:)

    integer::iError
    !-----------------------------------------------------------------------
    if(.not.allocated(RayValue_VI)) &
         allocate(RayValue_VI(nVarRay,nRay), RayValueAll_VI(nVarRay,nRay))

    RayValue_VI = 0.0
    iCell_D     = 1 ! set the index for ignored dimensions

    ! Loop through the rays
    do iRay = 1, nRay

       if(Unused_I(iRay)) CYCLE

       ! Find the processor, block and grid cell containing the ray
       call interpolate_grid(Position_DI(:,iRay), nCell, iCell_II, Weight_I)

       do iCell = 1, nCell

          ! Extract block and cell indexes. Should work in 2D too.
          iBlock          = iCell_II(0,iCell)
          iCell_D(1:nDim) = iCell_II(1:nDim,iCell)

          i      = iCell_D(1)
          j      = iCell_D(2)
          k      = iCell_D(3)
          Weight = Weight_I(iCell)

          ! Calculate the ionization level
          call user_material_properties( &
               State_V=State_VGB(:,i,j,k,iBlock), &
               NAtomicOut=NAtomicSI,              &
               TeOut=TeSI,                        &
               AverageIonChargeOut=zAverage)

          ! Increase Z for weakly ionized plasma to 1
          zAverage = max(zAverage, 1.0)

          ! Rho*Z in SI units
          RhoZSi = State_VGB(rho_,i,j,k,iBlock)*ZAverage*No2Si_V(UnitRho_)

          ! Calculate the absorption rate
          call calc_absorption(&
               NAtomicSI  = NAtomicSI, &
               ZAverage   = ZAverage, &
               TeSI       = TeSi, &
               RhoSI      = RhoZSi,&
               Absorption = Absorption)

          ! Interpolate density*Z
          RayValue_VI(RhoZ_,iRay) = RayValue_VI(RhoZ_,iRay) &
               + Weight * RhoZSi

          ! Interpolate absorption rate
          RayValue_VI(Absorption_,iRay) = RayValue_VI(Absorption_,iRay) &
               + Weight * Absorption

          ! If speed is an issue in the following lines, we can always
          ! calculate Zaverage a-priori and store it in tmp1_BLK

          ! Interpolate (X gradient of Rho*Z)
          call user_material_properties( &
               State_V=State_VGB(:,i+1,j,k,iBlock), &
               AverageIonChargeOut=ZaverageR)
          call user_material_properties( &
               State_V=State_VGB(:,i-1,j,k,iBlock), &
               AverageIonChargeOut=ZaverageL)
          ZaverageR = max(ZaverageR,1.0)
          ZaverageL = max(ZaverageL,1.0)
          RayValue_VI(GradXRhoZ_,iRay) = RayValue_VI(GradXRhoZ_,iRay) &
               + Weight * &
               ( ZaverageR*State_VGB(Rho_,i+1,j,k,iBlock) &
               - ZaverageL*State_VGB(Rho_,i-1,j,k,iBlock) ) &
               * No2Si_V(UnitRho_) * 0.5 / CellSize_DB(1,iBlock)

          ! Interpolate (Y gradient of Rho*Z)
          if(nDim > 1)then
             call user_material_properties( &
                  State_V=State_VGB(:,i,j+1,k,iBlock), &
                  AverageIonChargeOut=ZaverageR)
             call user_material_properties( &
                  State_V=State_VGB(:,i,j-1,k,iBlock), &
                  AverageIonChargeOut=ZaverageL)
             ZaverageR = max(ZaverageR,1.0)
             ZaverageL = max(ZaverageL,1.0)
             RayValue_VI(GradYRhoZ_,iRay) = RayValue_VI(GradYRhoZ_,iRay) &
                  + Weight * &
                  ( ZaverageR*State_VGB(Rho_,i,j+1,k,iBlock) &
                  - ZaverageL*State_VGB(Rho_,i,j-1,k,iBlock) ) &
                  * No2Si_V(UnitRho_) * 0.5 / CellSize_DB(2,iBlock)
          end if

          ! Interpolate (Z gradient of Rho*Z)
          if(nDim==3)then
             call user_material_properties( &
                  State_V=State_VGB(:,i,j,k+1,iBlock), &
                  AverageIonChargeOut=ZaverageR)
             call user_material_properties( &
                  State_V=State_VGB(:,i,j,k-1,iBlock), &
                  AverageIonChargeOut=ZaverageL)
             ZaverageR = max(ZaverageR,1.0)
             ZaverageL = max(ZaverageL,1.0)
             RayValue_VI(GradZRhoZ_,iRay) = RayValue_VI(GradZRhoZ_,iRay) &
                  + Weight * &
                  ( ZaverageR*State_VGB(Rho_,i,j,k+1,iBlock) &
                  - ZaverageL*State_VGB(Rho_,i,j,k-1,iBlock) ) &
                  * No2Si_V(UnitRho_) * 0.5 / CellSize_DB(3,iBlock)
          end if

          ! Use the interpolated cell size to set the ray step size
          RayValue_VI(CellSize_,iRay) = RayValue_VI(CellSize_,iRay) &
               + Weight * minval(CellSize_DB(1:nDim,iBlock))

       end do

    end do

    ! Collect information from all processors
    if(nProc > 1)then
       call MPI_allreduce(RayValue_VI, RayValueAll_VI, nRay*nVarRay,&
            MPI_REAL, MPI_SUM, iComm, iError)
       RayValue_VI = RayValueAll_VI
    end if

    ! Put it into individual arrays
    do iRay = 1, nRay
       GradDensity_DI(:,iRay) = RayValue_VI(GradXRhoZ_:GradZRhoZ_,iRay)
       Density_I(iRay)        = RayValue_VI(RhoZ_,iRay)
       AbsorptionCoeff_I(iRay)= RayValue_VI(Absorption_,iRay)
       DeltaSNew_I(iRay)      = RayValue_VI(CellSize_,iRay)
    end do

  end subroutine get_density_and_absorption

  !============================================================================

  subroutine ray_path(get_plasma_density, nRay, UnusedRay_I, Slope_DI, &
       DeltaS_I, ToleranceInit, DensityCr, Intensity_I, IsBehindCr_I)

    !
    !   The subroutine ray_path() makes raytracing and emissivity integration
    ! along ray paths. It works on a group of rays (a beam). Each ray is
    ! specified by its Cartesian Position_DI and its direction cosines 
    ! Slope_DI. The subroutine calculates new Position_DI, which is 
    ! DeltaS_I away from the initial position. It calculates the intensity
    ! along the step as emissivity multiplied by DeltaS and adds this to the
    ! Intensity_I. Thus, after series of calls to ray_path(), the Intensity_I
    ! contains the result of integration along the paths of every ray. 
    !   The electromagnetic rays are refracted in plasma due to its non-zero
    ! refractive index, which is the square root of the dielectric
    ! permittivity \epsilon. The \epsilon, in turn, is a function of the 
    ! plasma density. The external subprogram, get_plasma_density(),
    ! provides the plasma Density_I along with its gradient, GradDensity_DI,
    ! at the Position_DI. The \epsilon can be calculated as
    !         1 - Density_I/DensityCr, 
    ! where DensityCr is the "critical" plasma density at which the dielectric
    ! permittivity \epsilon falls down to zero. The value of DensityCr is
    ! proportional to the square of the wave frequency. For example,
    ! for the 42.3 MHz radiowaves the critical density is
    ! ~3.71x10^(-17) g/cm^3. A surface where the plasma density achieves the
    ! critical value acts like a a mirror. No radiation penetrates the
    ! critical surface. The radiowaves can only travel in the regions
    ! with lower density.
    !   The emissivity w of plasma at a selected plasma frequency is
    ! calculated as a polynomial function
    !         w = (Dens2DensCr)^2*(0.5 - Dens2DensCr)^2,
    ! where Dens2DensCr is the quotient Density_I/DensityCr. So, here the
    ! plasma density is used for calculation of both emissivity
    ! and dielectric permittyvity.
    !
    !   The ray refraction and plasma emissivity calculation is based solely
    ! on the plasma density. The density is obtained from the MHD simulation.
    ! The density data are located in the memories of several processors, and
    ! the get_plasma_density() program from the ModDensityAndGradient module
    ! makes the density acquisition. 
    ! 
    !   The parameters of the ray_path() are briefly described below.
    !
    ! get_plasma_density():  external subroutine that returns the plasma
    !     Density_I and its gradient GradDensity_DI. It also provides the
    !     recommended step size DeltaSNew_I and asserts the IsBehindCr_I (sets
    !     it to .true.) for a ray should it (illegally) penetrate into the
    !     region with "negative" dielectric permittivity.
    ! nRay:           number of rays being processed.
    ! UnusedRay_I:  the caller program can use this logical array to stop
    !     processing of any individual ray when it already finished travelling
    !     inside of a specified part of space. Set the corresponding element
    !     of UnusedRay_I to .true. to leave it unprocessed during the
    !     subsequent calls to ray_path(). Before the first call to ray_path()
    !     all the elements of UnusedRay_I should be set to .false.; then all
    !     the rays will be processed.
    ! Position_DI:    Cartesian position vectors of the rays.
    ! Slope_DI:       Direction cosines of the rays.
    ! DeltaS_I:       Current step values for the rays. Set the elements of
    !     Delta_I to some reasonable value, say, 1.0. The DeltaS_I elements
    !     are individually modified by ray_path() to satisfy the precision
    !     requirements set by ToleranceInit.
    ! ToleranceInit:   determines the precision of ray paths calculation.
    !     ToleranceInit is the inverse of the minimum number of ray
    !     trajectory points per one radian of the ray curvature. If this
    !     requirement is not satisfied, the corresponding element of DeltaS_I
    !     is decreased. Do not set the ToleranceInit to any value greater than
    !     0.1 (which means 10 points per curvature radian): it will be
    !     internally reduced to 0.1 anyway.   
    ! DensityCr: the plasma density at which its dielectric permittivity
    !     becomes zero for chosen wave frequency.
    ! Intensity_I:    the intensities of each ray calculated as the integral
    !     of emissivity along the ray path. During each call to ray_path(),
    !     each element of the Intensity_I is incremented by the integral along
    !     the step DeltaS_I. Set all the elements of Intensity_I to 0.0 before
    !     the first call to the ray_path().
    ! IsBehindCr_I:      the .true. elements of this logical array indicate that
    !     the corresponding rays penetrated into the "prohibited" region of
    !     space with the plasma density above its critical value. Normally, it
    !     should never happen. However, in case the algorithm made such an
    !     error, the flagged rays should be considered as "bad" and thrown
    !     away from the resultant Intensity_I. Set all the elements of
    !     IsBehindCr_I to .false. before calling ray_path() for the first time.
    ! 
    ! Written by Leonid Benkevitch.
    !
    !

    interface
       subroutine get_plasma_density(nRay)
         implicit none
         integer,intent(in) :: nRay
       end subroutine get_plasma_density
    end interface

    integer, intent(in) :: nRay   ! # of pixels in the raster
    real,    intent(inout), dimension(3,nRay) :: Slope_DI
    real,    intent(inout), dimension(nRay) :: Intensity_I, DeltaS_I
    real,    intent(in) ::  ToleranceInit, DensityCr

    ! .true. if a ray is OK, .false. otherwise:
    logical, intent(inout), dimension(nRay):: IsBehindCr_I

    ! a ray is excluded from processing if it is .true. 
    logical, intent(inout), dimension(nRay) :: UnusedRay_I   

    logical, save:: IsNewEntry = .true.

    integer, parameter :: nSplitDeltaS = 2

    real,    save, dimension(3)       :: Slope1_D, Omega_D
    real,    save, dimension(3)       :: ProjSlopeOnMinusGradEps_D
    real,    save, dimension(3)       :: StepX_D, StepY_D, RelGradRefrInx_D 
    real,    save, dimension(3)       :: GradDielPerm_D, PositionHalfBack_D

    real, save, pointer, dimension(:)   :: DistanceToCritSurf_I

    ! IsOKRay_I: .true. for shallow rays; is set to .false. for steep rays.
    logical, save, pointer, dimension(:)   :: IsOKRay_I       


    real :: HalfDeltaS                        ! DeltaS halved
    real :: DielPerm, DielPermHalfBack, Dens2DensCr
    real :: Coef, Curv, Curv1
    real :: LCosAl ! L*cos(Alpha),   
    ! where L is inverse grad of \epsilon, Alpha is the incidence angle
    real :: GradDielPermSqr, GradEpsDotSlope
    real :: ParabLen
    real, save :: &
         Tolerance=0.1, ToleranceSqr=1.0e-2, DensityCrInv=1, StepMin=1

    integer, save :: nCall=0
    integer:: iRay, iDim

    character(LEN=20),save:: TypeBoundaryDown_D(nDim), TypeBoundaryUp_D(nDim)
    !------------------------------------------------------------------------

    if (IsNewEntry) then
       IsNewEntry = .false.
       allocate(DistanceToCritSurf_I(nRay))
       DistanceToCritSurf_I = cZero
       allocate(IsOKRay_I(nRay))
       IsOKRay_I = .true.
       DensityCrInv = cOne/DensityCr

       !  minimum ten points between a vacuum and a critical surface and
       !  minimum 10 points over 1 rad of the curvature
       Tolerance = min(ToleranceInit,0.1)  


       ToleranceSqr = Tolerance**2 

       ! One (ten-thousandth) hundredth of average step 
       StepMin = 1e-2*sum(DeltaS_I)/nRay
       do iDim=1,nDim
          TypeBoundaryDown_D(iDim) = trim(TypeBc_I(2*iDim-1))
          TypeBoundaryUp_D(iDim)   = trim(TypeBc_I(2*iDim))
       end do
       !if(iProc==0)then
       !   write(*,*)'TypeBoundaryDown_D=',TypeBoundaryDown_D
       !   write(*,*)'TypeBoundaryUp_D=',TypeBoundaryUp_D
       !   write(*,*)'StepMin=',StepMin
       !end if

    end if

    nCall = nCall + 1

    !Start the predictor step of the GIRARD scheme: 
    do iRay = 1, nRay
       if (UnusedRay_I(iRay)) CYCLE  ! Do not process the rays that are done
       Position_DI(:,iRay) = Position_DI(:,iRay) + &
            Slope_DI(:,iRay)*cHalf*DeltaS_I(iRay) 
       ! Now Position_DI moved by 1/2 DeltaS !!!
       call check_bc
    end do

    !
    ! The following routine collects the density values at the Position_DI
    ! from all relevant processors
    !

    call get_plasma_density(nRay)


    ! In making radio images this is a bad pixel which should be further processed 
    IsBehindCr_I = Density_I>= DensityCr.and..not.UnusedRay_I
    UnusedRay_I = UnusedRay_I .or. IsBehindCr_I ! "bad rays" are done

    !In solving the laser deposition energy the total remnant energy 
    !should be deposited if the ray pamatrates through the critical surface
    if(UseLaserHeating)then
       where( IsBehindCr_I)
          EnergyDeposition_I = Intensity_I
          Intensity_I = 0.0
       endwhere
    end if

    do iRay = 1, nRay

       if (UnusedRay_I(iRay)) CYCLE  ! Do not process the rays that are done


       HalfDeltaS = cHalf*DeltaS_I(iRay)
       ! Original Position (at an integer point):
       PositionHalfBack_D = Position_DI(:,iRay) - Slope_DI(:,iRay)*HalfDeltaS
       Dens2DensCr = Density_I(iRay)*DensityCrInv

       DielPerm = cOne - Dens2DensCr
       GradDielPerm_D = -GradDensity_DI(:,iRay)*DensityCrInv
       GradDielPermSqr = sum(GradDielPerm_D**2)

       GradEpsDotSlope = sum(GradDielPerm_D*Slope_DI(:,iRay))

       DielPermHalfBack = DielPerm  - GradEpsDotSlope*HalfDeltaS

       !Check positivity:
       if( DielPermHalfBack<=0.0)then
          IsBehindCr_I(iRay) = .true.
          if(UseLaserHeating)then
             EnergyDeposition_I(iRay) = Intensity_I(iRay)
             Intensity_I(iRay) = 0.0
          end if
          CYCLE
       end if

       Curv = (cHalf*HalfDeltaS/DielPermHalfBack)**2* &
            (GradDielPermSqr - GradEpsDotSlope**2)
       !The curvature squared characterizes the magnitude of
       !the tranverse gradient of the dielectric permittivity

       if (IsOKRay_I(iRay)) then

          !
          ! Check if the trajectory curvature is too sharp
          ! to meet the Tolerance. If so, reduce the DeltaS 
          ! step for the iRay-th ray and leave it until
          ! the next call.
          !
          !

          if (Curv .ge. ToleranceSqr) then
             DeltaS_I(iRay) = 0.99 * &
                  DeltaS_I(iRay)/(2*sqrt(Curv/ToleranceSqr))
             Position_DI(:,iRay) = PositionHalfBack_D
             if(UseLaserHeating)EnergyDeposition_I(iRay) = 0.0
             CYCLE
          end if
          !if(UseLaserHeating)then
          !   !Check if the absorption is too high
          !   if(AbsorptionCoeff_I(iRay) * DeltaS_I(iRay)>=0.5)then
          !      DeltaS_I(iRay) =  max(&
          !           cHalf/AbsorptionCoeff_I(iRay),&
          !           StepMin)
          !      Position_DI(:,iRay) = PositionHalfBack_D
          !      if(UseLaserHeating)EnergyDeposition_I(iRay) = 0.0
          !      CYCLE
          !   end if
          !end if
          !
          ! Test if some of the next points can get into the prohibited
          ! part of space with "negative" dielectric permittivity
          !
          ! Here we check the magnitude of the longitudinal gradient
          ! of the dielectric permittivity

          if (3*GradEpsDotSlope*HalfDeltaS <= -DielPermHalfBack) then
             !
             ! Mark the ray as steep; 
             ! memorize the distance to the critical surface;
             ! reduce step
             !
             IsOKRay_I(iRay) = .false.
             DistanceToCritSurf_I(iRay) = DielPermHalfBack  &
                  /sqrt(GradDielPermSqr)
             DeltaS_I(iRay) =  max(&
                  cHalf*Tolerance*DistanceToCritSurf_I(iRay),&
                  StepMin)
             Position_DI(:,iRay) = PositionHalfBack_D
             if(UseLaserHeating)EnergyDeposition_I(iRay) = 0.0
             CYCLE
          end if

       end if ! IsOKRay_I

       !
       ! Either switch to opposite pranch of parabola
       ! or make a Boris step
       !

       if ((3*GradEpsDotSlope*HalfDeltaS <= -DielPermHalfBack)&
            .or.(DeltaS_I(iRay)<StepMin.and.&
            GradEpsDotSlope<0)) then

          ! Switch to the opposite branch of parabolic trajectory
          !
          ! When a next step can drive the ray into the area with the
          ! plasma density greater then its critical value, then a special 
          ! technique of "parabolic ray reflection" is employed. 
          ! It can be shown that a ray trajectory in the medium with constant
          ! gradient of dielectric permittivity is a parabola. If the step
          ! DeltaS_I is small enough we can assume the grad \epsilon constant
          ! and hence assume that the ray approaches the critical surface 
          ! in a parabolic path.
          ! We calculate the parameters of the parabola, namely:
          ! StepX_D -- vector along the -grad \epsilon, with the length equal 
          !     to the distance from the PositionHalfBack_D to the parabola 
          !     extremum;  
          ! StepY_D -- vector perpendicular to StepX_D, lying inside of the
          !     parabola plane, pointing at the opposite parabola branch, and
          !     with the length equal the distance from PositionHalfBack_D to
          !     the opposite branch of parabola.
          ! The parabolic reflection is just a replacement of the Position_DI
          ! with the symmetric point at the opposite branch of parabola, and 
          ! changing the "incident" direction Slope_DI to the "departing" ray
          ! direction according to Snell law.
          !

          LCosAl = -GradEpsDotSlope/GradDielPermSqr
          ProjSlopeOnMinusGradEps_D = -LCosAl*GradDielPerm_D  
          ! Here v_proj

          StepY_D = Slope_DI(:,iRay) - ProjSlopeOnMinusGradEps_D 
          ! Here c; |c| = sin \alpha

          Slope_DI(:,iRay) = Slope_DI(:,iRay) - 2*ProjSlopeOnMinusGradEps_D

          !
          ! We need to have 
          !   |Step_Y| = 4 * sin(\alpha)*cos(\alpha)*DielPermHalfBack*L
          ! Now the direction of Step_Y is right, the length of it is equal
          ! to  sin(\alpha).
          ! Multiply it by L*Cos(\alpha)*DielPermHalfBack
          !

          StepY_D = 4*StepY_D*LCosAl*DielPermHalfBack 

          Position_DI(:,iRay) = PositionHalfBack_D + StepY_D

          !
          ! Step_X is in the direction of - grad \epsilon,
          ! whose vector is of the length of 1/L.
          ! The length of Step_X is cos^2(\alpha)*L*DielPermHalfBack 
          ! Thus,
          !

          StepX_D = (DielPermHalfBack*LCosAl**2)*GradDielPerm_D


          ParabLen = sqrt(sum((2*StepX_D)**2) + sum(StepY_D**2))
          if(.not.UseLaserHeating)then
             Intensity_I(iRay) = Intensity_I(iRay)  &
                  + ParabLen*(Dens2DensCr**2)*(cHalf - Dens2DensCr)**2
          else
             EnergyDeposition_I(iRay) = Intensity_I(iRay) * &
                  ParabLen * AbsorptionCoeff_I(iRay)

             ! if(UseLaserHeating)then missing ???

             if(EnergyDeposition_I(iRay)>=Intensity_I(iRay))then
                !Mark this ray as if it is behind the critical surface
                EnergyDeposition_I(iRay) = Intensity_I(iRay)
                UnusedRay_I(iRay) = .true.
                Intensity_I(iRay) = 0.0
                IsBehindCr_I(iRay) = .true.
                CYCLE
             end if
             Intensity_I(iRay) = Intensity_I(iRay) * &
                  (1 - ParabLen * AbsorptionCoeff_I(iRay)) 
          end if

       else 

          ! Make a step using Boris' algorithm

          Coef=cHalf*HalfDeltaS/(cOne - Dens2DensCr)
          RelGradRefrInx_D = Coef*GradDielPerm_D    
          ! grad(n) = grad(eps(i+1/2))/(2*eps(i+1/2))

          Omega_D = cross_product(RelGradRefrInx_D, Slope_DI(:,iRay))
          Slope1_D = Slope_DI(:,iRay) &
               + cross_product(Slope_DI(:,iRay), Omega_D)

          Omega_D = cross_product(RelGradRefrInx_D, Slope1_D)
          Slope1_D = Slope_DI(:,iRay) &
               + cross_product(Slope_DI(:,iRay), Omega_D)

          Curv1 = sum(Omega_D**2)
          Coef = 2/(1 + Curv1)
          Slope_DI(:,iRay) = Slope_DI(:,iRay) &
               + Coef*cross_product(Slope1_D, Omega_D)

          Position_DI(:,iRay) = Position_DI(:,iRay) &
               + Slope_DI(:,iRay)*HalfDeltaS
          if(UseLaserHeating)then
             EnergyDeposition_I(iRay) = Intensity_I(iRay) *  &
                  DeltaS_I(iRay) * AbsorptionCoeff_I(iRay)
             if(EnergyDeposition_I(iRay)>=Intensity_I(iRay))then
                !Mark this ray as if it in behind the critical surface
                EnergyDeposition_I(iRay) = Intensity_I(iRay)
                Intensity_I(iRay) = 0.0
                UnusedRay_I(iRay) = .true.
                IsBehindCr_I(iRay) = .true.
                CYCLE
             end if
             Intensity_I(iRay) = Intensity_I(iRay) * &
                  (1 - DeltaS_I(iRay) * AbsorptionCoeff_I(iRay)) 
          else
             Intensity_I(iRay) = Intensity_I(iRay) &
                  + DeltaS_I(iRay)*(Dens2DensCr**2)*(cHalf - Dens2DensCr)**2
          end if
       end if

       call check_bc

       !
       !   The code below makes gradual increases of the DeltaS up to the value
       ! specified in DeltaSNew. The smooth step increase is required so as
       ! not to get into the space behind the critical surface, stepping with
       ! DeltaS that instantly changes from a very little size to the normal
       ! DeltaSNew length. DeltaS is usually reduced in a close vicinity of 
       ! the critical surface, where the ray is travelling along a very sharp
       ! curve with high curvature. For many rays it means fractioning of the
       ! DeltaS down several orders of magnitude, therefore the new step trial
       ! should start from a bigger step of the same order of magnitude.
       !   This problem is solved using a non-linear difference equation:
       !           Y(i+1) = [2 - Y(i)/X(i)]*Y(i),
       ! where X(i) is the desired final DeltaS length from DeltaSNew, and
       ! Y(i) is the actual DeltaS length. A brief analysis of the equation
       ! shows that, when Y is small compared to X, the next value of Y will
       ! be almost 2*X, so the DeltaS would grow in a geometrical progression.
       ! However, as Y approaches X, its growth rate becomes slower. However,
       ! Y always reaches X in several steps. One can check that for Y = X the
       ! next value of Y is always that of X.
       !     The behaviour of Y can also be characterized as exponential
       ! growth when Y is close to zero, and exponential saturation when Y is
       ! close to X. 
       ! 
       if (IsOKRay_I(iRay)) then
          !
          ! For shallow rays the DeltaS is increased unconditionally
          !
          DeltaS_I(iRay) = max(2 - DeltaS_I(iRay)/DeltaSNew_I(iRay),1.0)*&
               min(DeltaSNew_I(iRay), DeltaS_I(iRay))
       else 
          !
          ! If the iRay-th ray is marked as steep (i.e. "not gentle" or "not
          ! shallow") then the code below increases its DeltaS only if the
          ! current distance to the critical surface, calculated as
          !      \epsilon / grad \epsilon,
          ! is greater than this distance value saved along with marking the
          ! ray as steep in the DistanceToCritSurf_I. 
          !   This can happen in two cases: 
          ! (1) either the ray was "parabola reflected" and
          ! after several steps it went away from the surface by the distance
          ! where the parabola switching occurred; 
          ! (2)or the ray is not steep any more because 
          ! the current DeltaS is so small, that the next step does not
          ! penetrate the critical surface.
          !   The ray is reverted to "gentle" or "shallow"
          !
          if (DielPermHalfBack .gt. &
               DistanceToCritSurf_I(iRay)*sqrt(GradDielPermSqr)) then
             IsOKRay_I(iRay) = .true.
             DeltaS_I(iRay) = max(2 - DeltaS_I(iRay)/DeltaSNew_I(iRay), 1.0)*&
                  min(DeltaSNew_I(iRay), DeltaS_I(iRay))
          end if
       end if
    end do
  contains
    !=======================================================================
    subroutine check_bc

      integer::iDim
      !--------------------------------------------------------------------
      do iDim = 1, nDim
         if(Position_DI(iDim, iRay) < XyzMin_D(iDim))then
            if(TypeBoundaryDown_D(iDim)=='reflect')then
               Position_DI(iDim, iRay) = &
                    2 * XyzMin_D(iDim) -  Position_DI(iDim, iRay)
               Slope_DI(iDim, iRay) = - Slope_DI(iDim, iRay)
            else
               UnusedRay_I(iRay) = .true.
               return
            end if
         else if(Position_DI(iDim, iRay) > XyzMax_D(iDim))then
            if(TypeBoundaryUp_D(iDim)=='reflect')then
               Position_DI(iDim, iRay) = &
                    2 * XyzMax_D(iDim) -  Position_DI(iDim, iRay)
               Slope_DI(iDim, iRay) = - Slope_DI(iDim, iRay)
            else
               UnusedRay_I(iRay) = .true.
               return
            end if
         end if
      end do
    end subroutine check_bc
    !====================
  end subroutine ray_path

  !============================================================================

  real function irradiance_t(TimeSi)

    real,intent(in)::TimeSi
    !----------------------

    if (TimeSi > tPulse) UseLaserHeating = .false.

    !irradiance_t = IrradianceSi *&
    !     max(0.0, min(1.0,       &
    !     (TimeSi/tRaise)**3,     &
    !     (tPulse -TimeSi)/tDecay))

    if(DoLaserRayTest)then
       !no temporal profile
       irradiance_t = IrradianceSi
    else
       !top hat profile
       irradiance_t = IrradianceSi * &
            max(0.0, min(1.0,        &
            (TimeSi/tRaise),         &
            (tPulse - TimeSi)/tDecay))
    end if

  end function irradiance_t

  !============================================================================
  subroutine get_rays

    !--------------------------------------------------------------------------
    select case(TypeBeam)
    case('rz','RZ')
       call rz_beam_rays
    case('rz2','RZ2')
       call rz2_beam_rays
    case('2d','2D','3d', '3D')
       call stop_mpi('TypeBeam='//TypeBeam//' is not yet implemented')
    case default
       call stop_mpi('Unknown TypeBeam='//TypeBeam)
    end select

    !Normalize amplitudes:
    Amplitude_I(1:nRayTotal) = Amplitude_I(1:nRayTotal)/&
         sum(Amplitude_I(1:nRayTotal))
  end subroutine get_rays

  !===========================================================================

  subroutine rz_beam_rays

    use BATL_lib,    ONLY: CoordMin_D, CoordMax_D
    use ModGeometry, ONLY: TypeGeometry, y2
    use ModConst,    ONLY: cDegToRad, cTwoPi

    real:: CosTheta, SinTheta,  yCrCentral, yPlaneCentral, yPlane
    real:: rDistance, BeamAmplitude
    integer:: iRay, iBeam, iRayStart, iRayStop
    !--------------------------------------------------------------------------

    if(TypeGeometry/='rz')call CON_stop(&
         'Dont use TypeBeam='//TypeBeam//' with TypeGeometry='//TypeGeometry)

    ! A computational wedge of one radian in the ignorable direction is used
    IrradianceSi = IrradianceSi*(CoordMax_D(3) - CoordMin_D(3))/cTwoPi

    ! Allocation is excessive, nRayTotal is not yet known:

    allocate(  XyzRay_DI(3, nBeam * (2 * nRayPerBeam +1)))
    allocate(SLopeRay_DI(3, nBeam * (2 * nRayPerBeam +1)))
    allocate(Amplitude_I(nBeam * (2 * nRayPerBeam +1)))

    nRayTotal = 0
    do iBeam = 1, nBeam
       cosTheta =  cos(cDegToRad * BeamParam_II(SlopeDeg_, iBeam))

       !Positive direction of the slope is taken for the beams
       !converging to the axis:

       sinTheta = -sin(cDegToRad * BeamParam_II(SlopeDeg_, iBeam))

       ! Transform yCr to dimensionless
       yCrCentral =  BeamParam_II(yCr_, iBeam)

       yPlaneCentral = yCrCentral + xPlane*SinTheta/CosTheta

       BeamAmplitude = BeamParam_II(AmplitudeRel_,iBeam)

       if(DoLaserRayTest)then
          iRayStart = 1
          iRayStop  = 1
       else
          iRayStart =-nRayPerBeam
          iRayStop  = nRayPerBeam
       end if

       do iRay = iRayStart, iRayStop
          !We neglect exp(-2.25)\approx0.1 and chose the beam margin
          !to be at 1.5 rBeam from the central ray:

          rDistance = iRay * rBeam * 1.5 /nRayPerBeam 
          yPlane = yPlaneCentral + rDistance/CosTheta

          !Do not include rays with the starting point 
          !being otside the computational domain:
          if(abs(yPlane) >= y2)CYCLE
          nRayTotal = nRayTotal + 1

          if(DoLaserRayTest)then
             Amplitude_I(nRayTotal) = BeamAmplitude
          else
             ! supergaussian spatial profile
             Amplitude_I(nRayTotal) = BeamAmplitude &
                  *exp(-(abs(rDistance)/rBeam)**SuperGaussianOrder) &
                  *abs(yCrCentral + rDistance/CosTheta)
          end if

          if(yPlane > 0)then
             XyzRay_DI(:,nRayTotal) = (/xPlane, yPlane, 0.0/)
             SlopeRay_DI(:,nRayTotal) = (/CosTheta, SinTheta, 0.0/)
          else
             XyzRay_DI(:,nRayTotal) = (/xPlane, -yPlane, 0.0/)
             SlopeRay_DI(:,nRayTotal) = (/CosTheta, -SinTheta, 0.0/)
          end if

       end do ! iRay
    end do ! iBeam

  end subroutine rz_beam_rays

  !============================================================================

  subroutine rz2_beam_rays

    use BATL_lib,    ONLY: CoordMin_D, CoordMax_D
    use ModGeometry, ONLY: TypeGeometry, y2, minDXvalue
    use ModConst,    ONLY: cDegToRad, cTwoPi

    real:: CosTheta, SinTheta,  yCrCentral, yPlane
    real:: rDistance, BeamAmplitude
    integer:: iRay, iBeam

    !--------------------------------------------------------------------------

    if(TypeGeometry/='rz')call CON_stop(&
         'Dont use TypeBeam='//TypeBeam//' with TypeGeometry='//TypeGeometry)

    ! A computational wedge of one radian in the ignorable direction is used
    IrradianceSi = IrradianceSi*(CoordMax_D(3) - CoordMin_D(3))/cTwoPi

    ! Allocation is excessive, nRayTotal is not yet known:

    allocate(  XyzRay_DI(3, nBeam * (2 * nRayPerBeam +1)))
    allocate(SLopeRay_DI(3, nBeam * (2 * nRayPerBeam +1)))
    allocate(Amplitude_I(nBeam * (2 * nRayPerBeam +1)))

    nRayTotal = 0
    do iBeam = 1, nBeam
       cosTheta =  cos(cDegToRad * BeamParam_II(SlopeDeg_, iBeam))

       !Positive direction of the slope is taken for the beams
       !converging to the axis:

       sinTheta = -sin(cDegToRad * BeamParam_II(SlopeDeg_, iBeam))

       ! Transform yCr to dimensionless
       yCrCentral =  BeamParam_II(yCr_, iBeam)

       BeamAmplitude = BeamParam_II(AmplitudeRel_,iBeam)

!!$       do iRay = -nRayPerBeam, nRayPerBeam
       ! The following is conform the H2D strategy for following rays
       do iRay = 1, nRayPerBeam  !just for beams pointed at the symmetry axix

          !We neglect exp(-2.25)\approx0.1 and chose the beam margin
          !to be at 1.5 rBeam from the central ray:

          rDistance = iRay * rBeam * 1.5 /nRayPerBeam 

          ! Maps rDistance to laser-entry plane, applies shift set
          ! by yBeam in the PARAM.in file
          yPlane = yCrCentral + (rDistance + xPlane*sinTheta/cosTheta)

          !Dealing with rays starting outside the computational domain on laser-entry plane:
          ! Substracting minDXvalue from y2 so that the rays do not start on domain boundary
          if(abs(yPlane) >= y2)then
             !Do not let rays begin in target past drive surface
             if(sinTheta < 0.0 .and. &
                  xPlane + (abs(yPlane)-(y2-minDXvalue))*cosTheta/(-sinTheta) < 0.0)then
                xPlane = xPlane + (abs(yPlane)-(y2-minDXvalue))*cosTheta/(-sinTheta)
                yPlane = y2 - (minDXvalue)
             else	
                CYCLE
             endif
          endif


          if(yPlane <= 0.0)then
             !Do not let rays begin in target past drive surface
             if(xPlane + (yPlane+minDXvalue)*cosTheta/(-sinTheta) < 0.0)then
                xPlane = xPlane + (yPlane+minDXvalue)*cosTheta/(-sinTheta)
                yPlane = minDXvalue
             else	
                CYCLE
             endif
          endif

          nRayTotal = nRayTotal + 1

          if(DoLaserRayTest)then
             Amplitude_I(nRayTotal) = BeamAmplitude
          else
             ! supergaussian spatial profile
             Amplitude_I(nRayTotal) = BeamAmplitude &
                  *exp(-(abs(rDistance)/rBeam)**SuperGaussianOrder) &
                  *abs(yCrCentral + rDistance)
          end if

          XyzRay_DI(:, nRayTotal) = (/xPlane, yPlane, 0.0/)
          SlopeRay_DI(:, nRayTotal) = &
               (/CosTheta, SinTheta, 0.0/)

       end do
    end do
  end subroutine rz2_beam_rays

  !============================================================================

  subroutine read_laser_heating_param(NameCommand)

    use ModReadParam

    character(len=*), intent(in) :: NameCommand

    character(len=*), parameter:: NameSub = 'read_laser_heating_param'
    !-------------------------------------------------------------------------
    !Usage
    !#LASERPULSE
    !T                UseLaserHeating
    !3.8e12           IrradianceSI
    !1.1e-9           tPulse
    !1.0e-10          tRaise
    !1.0e-10          tDecay
    !
    !#LASERPOSITION
    !30               nRayPerBeam
    !438.0            rBeam
    !-100.0           xPlane
    !parallel         TypeConvergence
    !
    !#LASERBEAM
    !10.0             SlopeDeg
    !0.0              yBeam
    !1.0              AmplitudeRel
    !
    !#LASERBEAM
    !20.0             SlopeDeg
    !200.0            yBeam
    !0.7              AmplitudeRel
    !
    !#LASERBEAM
    !30.0             SlopeDeg
    !400.0            yBeam
    !0.7              AmplitudeRel
    !
    !-------------

    select case(NameCommand)
    case("#LASERPULSE")
       call read_var('UseLaserHeating', UseLaserHeating)
       if(UseLaserHeating)then
          call read_var('IrradianceSI'   , IrradianceSI   )
          call read_var('tPulse'         , tPulse         )
          call read_var('tRaise'         , tRaise         )
          call read_var('tDecay'         , tDecay         )
       end if
    case('#LASERBEAMS')
       call read_var('TypeBeam',    TypeBeam   )
       call read_var('nRayPerBeam', nRayPerBeam)
       call read_var('rBeam',       rBeam )
       call read_var('xBeam',       xPlane )
    case('#LASERBEAM')
       nBeam = nBeam +1
       call read_var('SlopeDeg', &
            BeamParam_II(SlopeDeg_, nBeam))
       call read_var('yBeam', &
            BeamParam_II(yCr_, nBeam))
       call read_var('AmplitudeRel', &
            BeamParam_II(AmplitudeRel_, nBeam))

    case('#LASERBEAMPROFILE')
       call read_var('SuperGaussianOrder', SuperGaussianOrder)

    case('#LASERRAYTEST')
       call read_var('DoLaserRayTest', DoLaserRayTest)
    case default
       call stop_mpi(NameSub//': unknown command='//NameCommand)
    end select

  end subroutine read_laser_heating_param

  !============================================================================

  subroutine init_laser_package

    use ModSize, ONLY: MaxBlock, nI, nJ, nK
    !----------------------------------------------------------------------
    DoInit = .false.
    call get_rays
    nRay = nRayTotal

    ! Allocate arrays for rays
    allocate(LaserHeating_CB(nI,nJ,nK,MaxBlock))
    LaserHeating_CB = 0.0

    if(nRay >0)then
       allocate(Density_I(nRay), GradDensity_DI(3,nRay),DeltaSNew_I(nRay))
       allocate(AbsorptionCoeff_I(nRay))
       allocate(EnergyDeposition_I(nRay))
       EnergyDeposition_I = 0.0
    end if

    ! write(*,*)'nRay, nRayTotal=', nRay, nRayTotal

    allocate(Position_DI(3,nRayTotal))

    allocate(DoRay_I(nRayTotal))

    allocate(Slope_DI(3, nRayTotal))
    allocate(Intensity_I(nRayTotal), DeltaS_I(nRayTotal))
    allocate(Unused_I(nRayTotal), IsBehindCr_I(nRayTotal))

    !Initialize all arrays:
    Position_DI(:, 1:nRayTotal) = XyzRay_DI(:,   1:nRayTotal)
    Slope_DI(:,    1:nRayTotal) = SlopeRay_DI(:, 1:nRayTotal)
    Intensity_I(   1:nRayTotal) = Amplitude_I(   1:nRayTotal)
    DoRay_I = .true.

    Unused_I = .false.; IsBehindCr_I = .false.

    DeltaS_I = DeltaS

    call get_density_and_absorption(nRayTotal)

!!$    if(DoVerbose .and. iProc==0)then
!!$       NameFile='Rays_n0000'
!!$       write(*,*)trim(NameFile)
!!$       open(UnitTmp_, file=NameFile, status='replace')
!!$       do iRay = 1, nRay
!!$          write(UnitTmp_,*)Position_DI(1:2,iRay), Density_I(iRay), &
!!$               GradDensity_DI(:,iRay), DeltaSNew_I(iRay), &
!!$               AbsorptionCoeff_I(iRay)
!!$       end do
!!$       close(UnitTmp_)
!!$    end if

  end subroutine init_laser_package
  !===========================================================================
  subroutine get_energy_source

    use BATL_lib, ONLY: nDim, MaxDim, nIJK_D, interpolate_grid, CoordMin_D

    integer:: iStep
    integer:: iRay, iBlock, iCell, nCell
    integer:: iCell_II(0:nDim,2**nDim), iCell_D(MaxDim), i, j, k
    real::    Weight_I(2**nDim), Weight

    integer:: iError
    real::    PosXHold, TurningPoint
    real::    SumLaserHeatingPe, SumLaserHeating, SumLaserHeatingRef
    !-----------------------------------------------------------------------
    if(DoInit) then
       call init_laser_package
       if(iProc==0.and.DoVerbose)then
          write(*,*)'Initialized laser package with nRay=', nRay
          write(*,*)'Critical density equals ',DensityCrSi
       end if
    end if

    !Initialize all arrays:
    Position_DI(:, 1:nRayTotal) = XyzRay_DI(:,   1:nRayTotal)
    Slope_DI(:,    1:nRayTotal) = SlopeRay_DI(:, 1:nRayTotal)
    Intensity_I(   1:nRayTotal) = Amplitude_I(   1:nRayTotal)
    DoRay_I                     = .true.
    EnergyDeposition_I          = 0.0
    LaserHeating_CB             = 0.0

    if(DoLaserRayTest) PosXHold = Position_DI(1,1)

    Unused_I = .false.; IsBehindCr_I = .false.
    DeltaS_I = DeltaS
    iStep = 0
    do while(.not.all(Unused_I))
       EnergyDeposition_I=0.0
       !Propagate each of rays through the distance of DeltaS
       call ray_path(get_density_and_absorption, nRay, Unused_I, Slope_DI, &
            DeltaS_I, Tolerance, DensityCrSi, Intensity_I, IsBehindCr_I)

       if (DoLaserRayTest) then
          if (Position_DI(1,1) > PosXHold) PosXHold = Position_DI(1,1)
       end if

!!$       if(DoVerbose .and. iProc==0)then
!!$          NameFile=''
!!$          write(NameFile,'(a,i4.4)')'Rays_n',iStep+1
!!$          write(*,*)trim(NameFile)
!!$          open(UnitTmp_, file=NameFile, status='replace')
!!$          do iRay = 1, nRay
!!$             if(Unused_I(iRay)) CYCLE
!!$             write(UnitTmp_,*)iRay,Position_DI(1:2,iRay), Slope_DI(:,iRay), &
!!$                  DeltaS_I(iRay),Density_I(iRay), AbsorptionCoeff_I(iRay), &
!!$                  GradDensity_DI(:,iRay), EnergyDeposition_I(iRay)
!!$          end do
!!$          close(UnitTmp_)
!!$       end if
       DoRay_I = (.not.Unused_I).or.IsBehindCr_I
       if(.not.any(DoRay_I))EXIT
       iStep = iStep + 1
!!$       if(DoVerbose .and. iProc==0 .and. .not.all(Unused_I))then
!!$          write(*,*)'Laser package at iStep =',iStep
!!$          write(*,*)'Used rays #=',count(.not.Unused_I)
!!$          write(*,*)'Rays penetrated into overdense plasma, #=', &
!!$               count(IsBehindCr_I)
!!$          write(*,*)'Total energy deposition =', &
!!$               sum(EnergyDeposition_I,MASK=DoRay_I)
!!$          write(*,*)'MinumumStep=',minval(DeltaS_I,MASK=.not.Unused_I)
!!$          write(*,*)'MaximumStep=',maxval(DeltaS_I,MASK=.not.unused_I)
!!$          write(*,*)'Min DeltaSNew_I=',minval(DeltaSNew_I,MASK=.not.Unused_I)
!!$       end if

       ! Save EnergyDeposition_I to LaserHeating_CB 
       ! using the interpolation weights
       iCell_D = 1 ! for ignored dimensions
       do iRay = 1, nRay

          if(.not.DoRay_I(iRay)) CYCLE

          ! Find the processor, block and grid cell containing the ray
          call interpolate_grid(Position_DI(:,iRay), nCell, iCell_II, Weight_I)

          do iCell = 1, nCell

             ! Extract block and cell indexes. Should work in 2D too.
             iBlock          = iCell_II(0,iCell)
             iCell_D(1:nDim) = iCell_II(1:nDim,iCell)

             ! Do not deposit energy into ghost cells at the outer boundaries
             if(  any(iCell_D(1:nDim) < 1) .or. &
                  any(iCell_D(1:nDim) > nIJK_D(1:nDim))) CYCLE

             i      = iCell_D(1)
             j      = iCell_D(2)
             k      = iCell_D(3)
             Weight = Weight_I(iCell)

             ! Deposit the energy 
             LaserHeating_CB(i,j,k,iBlock) = LaserHeating_CB(i,j,k,iBlock) &
                  + Weight*EnergyDeposition_I(iRay)

!!$             write(*,*)'!!! i,j,k,iBlock,Weight,Deposition,SourceE=',&
!!$                  i,j,k,iBlock,Weight,&
!!$                  EnergyDeposition_I(iRay),LaserHeating_CB(i,j,k,iBlock)

          end do
       end do

       DoRay_I = (.not.Unused_I)
    end do

    if(DoLaserRayTest)then
       !L=50 for the test
       TurningPoint = CoordMin_D(1) &
            + 50.0*cos(cDegToRad*BeamParam_II(SlopeDeg_,1))**2

       ! Sum laser heating for all processors
       SumLaserHeatingPe = sum(LaserHeating_CB)
       call MPI_reduce(SumLaserHeatingPe, SumLaserHeating, 1,  MPI_REAL, &
            MPI_SUM, 0, iComm, iError)

       ! for a linear density profile the absorbed energy is
       ! = 1 - exp[-(32.0/15.0 * EffectiveCollisionRate at the critical density
       ! * L * costheta**5)/cLightSpeed]
       SumLaserHeatingRef = 1.0-exp(-32.0/15.0*50.0e-6*(2e12/cLightSpeed) &
            *cos(cDegToRad*BeamParam_II(SlopeDeg_,1))**5)

       if(iProc == 0)then
          write(*,*)' '
          write(*,*)'maximum X position of ray = ', PosXHold
          write(*,*)'Analytical turning point = ', TurningPoint
          write(*,*)' '
          write(*,*)'sum laser heating = ', SumLaserHeating
          write(*,*)'Analytical fractional absorption = ', SumLaserHeatingRef
          write(*,*)' '
       end if
    end if

  end subroutine get_energy_source

  !===========================================================================
  subroutine add_laser_heating

    ! Calculate the source terms due to laser heating

    use ModSize, ONLY: nI, nJ, nK
    use ModPhysics, ONLY: Si2No_V, UnitEnergydens_, UnitX_, UnitT_
    use ModMain, ONLY: Time_Simulation, dt, nBlock, UnusedBLK
    use ModAdvance,  ONLY: State_VGB, p_, ExtraEint_, &
         UseNonConservative, UseElectronPressure, UseIdealEos
    use ModPhysics,  ONLY: inv_gm1, gm1, No2Si_V, &
         UnitP_, UnitEnergyDens_, ExtraEintMin
    use ModVarIndexes, ONLY: Pe_
    use ModGeometry, ONLY: x1, x_BLK
    use ModUser, ONLY: user_material_properties
    use ModEnergy, ONLY: calc_energy_cell
    use BATL_lib, ONLY: message_pass_cell, CellVolume_GB

    real:: Irradiance, EInternalSi, PressureSi
    integer :: iBlock, i, j, k, iP

    character(len=*), parameter:: NameSub = 'add_laser_heating'
    !--------------------------------------------------------------------------

    if(iProc==0 .and. DoVerbose) write(*,*)'Start ',NameSub

    call timing_start(NameSub)

    if(DoLaserRayTest)then
       do iBlock = 1, nBlock
          if(unusedBLK(iBlock)) CYCLE
          do k=1, nK; do j=1, nJ; do i=1, nI
             ! Denominator 50.0 is the distance to the critical surface.
             ! The beryllium is initially weakly ionized (Z=1), so that
             ! the electron density is like the mass density a linear profile.
             State_VGB(Rho_,i,j,k,iBlock) = (x_BLK(i,j,k,iBlock) - x1)/50.0 &
                  *DensityCrSI*Si2No_V(UnitRho_)
          end do; end do; end do
       end do
    end if

    Irradiance = irradiance_t(Time_Simulation) * &
         Si2No_V(UnitEnergydens_)*Si2No_V(UnitX_)**3/Si2No_V(UnitT_) * dt

    ! Make sure that the density is up-to-date in the ghost cells
    call message_pass_cell(nVar, State_VGB)
    call get_energy_source

    iP = p_
    if(UseElectronPressure) iP = Pe_

    ! Why ???
    if(UseNonConservative) &
         call stop_mpi(NameSub//' does not work with non-conservative')

    do iBlock = 1, nBlock
       if(UnusedBLK(iBlock))CYCLE

       do k = 1, nK; do j = 1, nJ; do i = 1, nI
          LaserHeating_CB(i,j,k,iBlock) = LaserHeating_CB(i,j,k,iBlock) &
               *Irradiance/CellVolume_GB(i,j,k,iBlock)

          if(UseIdealEos)then
             State_VGB(iP,i,j,k,iBlock) = State_VGB(iP,i,j,k,iBlock) &
                  + gm1*LaserHeating_CB(i,j,k,iBlock)
          else
             ! Single temperature:
             !   From update_states_MHD, we obtained p^*, e^* with ideal gamma
             !   and ExtraEInt^* with pure advection.
             !   Total energy density E^n+1  = e^* + ExtraEInt^* is conserved.
             !   Total internal energy Eint^n+1 = p^*/(g-1) + ExtraEInt^*
             ! Two temperature:
             !   From update_states_MHD, we obtained Pe^*, e^* with ideal gamma
             !   and ExtraEInt^* with pure advection.
             !   Total energy density E^n+1  = e^* + ExtraEInt^* is conserved.
             !   Electron internal energy Eint^n+1 = Pe^*/(g-1) + ExtraEInt^*
             EinternalSi = No2Si_V(UnitEnergyDens_) &
                  *(inv_gm1*State_VGB(iP,i,j,k,iBlock) &
                  + State_VGB(ExtraEint_,i,j,k,iBlock) &
                  + LaserHeating_CB(i,j,k,iBlock))

             ! Single temperature: determine p^n+1 = EOS( rho^n+1, Eint^n+1)
             ! Two temperature:   determine Pe^n+1 = EOS( rho^n+1, Eint^n+1)
             call user_material_properties(State_VGB(:,i,j,k,iBlock), &
                  i, j, k, iBlock, &
                  EinternalIn=EinternalSi, PressureOut=PressureSi)

             ! Set normalized pressure (electron pressure for two temperature)
             State_VGB(iP,i,j,k,iBlock) = PressureSi*Si2No_V(UnitP_)

             ! Set ExtraEint^n+1 = Eint^n+1 - p^n+1/(g -1)
             State_VGB(ExtraEint_,i,j,k,iBlock) = max(ExtraEintMin, &
                  Si2No_V(UnitEnergyDens_)*EinternalSi &
                  - inv_gm1*State_VGB(iP,i,j,k,iBlock))
          end if
       end do; end do; end do

       call calc_energy_cell(iBlock)
    end do

    call timing_stop(NameSub)

    if(iProc==0 .and. DoVerbose) write(*,*)'End ',NameSub

  end subroutine add_laser_heating

end module ModLaserHeating
