!^CFG COPYRIGHT UM
Module ModMain
  !\
  ! Get values of nBLK, nI, nJ, nK, and gcn from ModSize
  !/
  use ModKind
  use ModSize
  use ModVarIndexes

  implicit none

  save

  !\
  ! Version of BATSRUS
  !/
  real, parameter :: CodeVersion = 9.10
  real            :: CodeVersionRead = -1.0

  !\
  ! Standalone and component information
  !/
  ! In stand alone mode this variable is set to true
  logical             :: IsStandAlone = .false.

  ! Shall we use the BATL library. Note (10/17/2011):
  !   for constrained transport scheme the #DIVB command and 
  !   for non-cartesian grid the #GRIDGEOMETRY command set UseBatl=.false.
  logical :: UseBatl = .true.

  ! In the SWMF the BATSRUS may run as GM, SC or IH component
  character (len=2)   :: NameThisComp='GM'

  ! In hydro equations B_ = U_ is set.
  logical, parameter:: UseB = B_ /= U_

  !\
  ! Time stepping parameters and values.
  !/
  integer :: n_step, nOrder, nStage, iteration_number=0
  real :: dt, DtFixed, DtFixedOrig, DtFixedDim, Cfl, CflOrig, dt_BLK(nBLK)
  logical :: time_accurate = .true.,   &
       boris_correction    = .false.,  &
       UseBorisSimple      = .false.,  &
       time_loop           = .false.

  ! Limiting speed in the numerical diffusive flux (for implicit scheme only)
  real :: Climit = -1.0

  ! Fixed time step (for implicit scheme mostly)
  logical :: UseDtFixed

  !\
  ! Model Coupling variables
  !/
  ! Dimensions of the buffer grid between SC and IH
  logical :: UseHelioBuffer3D = .false.
  integer :: nPhiBuff = 90,   nThetaBuff = 45
  real    :: rBuffMin = 19.0, rBuffMax = 21.0 

  logical :: UseIe = .false.
  logical :: UsePw = .false.

  logical :: UseIm = .false.
  logical :: DoCoupleImPressure = .true.
  logical :: DoCoupleImDensity  = .false.
  logical :: DoFixPolarRegion   = .false.
  logical :: DoImSatTrace       = .false.    
  logical :: DoRbSatTrace       = .false.    
  real    :: rFixPolarRegion    = 5.0
  real    :: dLatSmoothIm       = -1.0
  real    :: TauCoupleIm        = 20.0

  logical :: UseRaytrace            = UseB
  logical :: DoMultiFluidIMCoupling = .false.

  ! Single space separated NameVar string containing all the variable
  ! names of NameVar_V (except for the fluid energies)
  character(len=500) :: NameVarCouple

  !\
  ! Parameters for the B0 field
  !/
  ! Intrinsic field B0 may or may not be used if UseB is true.
  logical :: UseB0        = UseB
  logical :: DoUpdateB0   = UseB
  real    :: Dt_UpdateB0  = 0.0001

  !\
  ! Coronal magnetic field (magnetogram + EE generator)
  !/

  logical:: UseMagnetogram=.false., UseEmpiricalSW = .false.

  !\
  ! Inner and outer boundaries
  !/
  ! Indexes for boundaries
  integer, parameter :: body1_   = -1
  integer, parameter :: body2_   = -2
  integer, parameter :: ExtraBc_ =  0

  ! Inner and outer boundary conditions
  character (len=20) :: TypeBc_I(body2_:top_) = 'float'

  ! Logicals for bodies
  logical :: Body1    = .false.
  logical :: UseBody2 = .false.
  logical :: UseOrbit=.true.

  !\
  ! Block AMR grid parameters
  !/

  ! Identifiers for the grid and decomposition changes
  integer :: iNewGrid=0, iNewDecomposition=0

  ! Logigal array for the blocks used (=.false.) on the given processor
  logical, dimension(nBLK) :: UnusedBLK

  ! nBlock is a maximum block index number used on the given processor
  ! nBlockMax is a maximum of nBlock over all the processors, 
  ! nBlockALL is total number of blocks used.
  
  integer :: nBlockMax, nBlock, nBlockALL
  integer :: nBlockExplALL, nBlockImplALL

  ! The index of the block currently being dealt with.
  integer :: GlobalBLK

  ! Unique index of blocks for all the processors
  integer, dimension(nBLK) :: global_block_number

  ! Parameters for block location among eight subcubes.
  ! T=top, B=bottom, S=south, N=north, E=east, W=west
  integer, parameter :: &
       LOC_TSE=1, &
       LOC_TSW=2, &
       LOC_BSW=3, &
       LOC_BSE=4, &
       LOC_BNE=5, &
       LOC_BNW=6, &
       LOC_TNW=7, &
       LOC_TNE=8

  ! Variable for setting AMR levels
  logical :: DoSetLevels = .false.

  ! Index limits for the cell faces (needed for the constrained trasnsport)
  integer, parameter :: nIFace=nI+1 
  integer, parameter :: nJFace=nJ+1
  integer, parameter :: nKFace=nK+1  

  integer:: &
       jMinFaceX=1, jMaxFaceX=nJ,&
       kMinFaceX=1, kMaxFaceX=nK,&
       iMinFaceY=1, iMaxFaceY=nI,&
       kMinFaceY=1, kMaxFaceY=nK,&
       iMinFaceZ=1, iMaxFaceZ=nI,&
       jMinFaceZ=1, jMaxFaceZ=nJ

  !\
  ! How to deal with div B = 0
  !/
  logical :: UseDivbSource    = UseB
  logical :: UseDivbDiffusion = .false.
  logical :: UseProjection    = .false.
  logical :: UseConstrainB    = .false.
  logical :: UseB0Source      = UseB
  logical :: UseHyperbolicDivb= .false.
  real    :: SpeedHypDim = -1.0, SpeedHyp = 1.0, SpeedHyp2 = 1.0
  real    :: HypDecay = 0.1
  
  !\
  ! More numerical scheme parameters
  !/
  ! Prolongation order (1 or 2) and type ('central','lr','minmod','central2'..)
  integer           :: prolong_order = 1
  character(len=10) :: prolong_type  = 'lr'

  ! Message passing mode ('dir', 'opt', 'all', 'allopt' ...)
  character(len=10) :: optimize_message_pass = 'allopt'

  !\
  ! Source terms
  !/

  !\
  ! If the B0 filed is not assumed to be curl free (like in a tokamak or 
  ! in the solar corona beyond the source surface, the curl B0 x B force
  ! should be included to the momentum equation
  !/
  logical::UseCurlB0=.false.
  real::rCurrentFreeB0=-1.0

  ! Logicals for adding radiation diffusion and heat conduction
  logical :: UseRadDiffusion = .false.
  logical :: UseHeatConduction = .false.
  logical :: UseIonHeatConduction = .false.

  ! Logical and type for gravity
  logical :: UseGravity = .false.
  integer :: GravityDir = 0
  real    :: GravitySi = 0.0

  !\
  ! Rotation and coordinate system
  !/

  ! Logical for rotating inner boundary
  logical          :: UseRotatingBc = .false.

  ! Coordinate system
  character(len=3) :: TypeCoordSystem = 'GSM'

  ! Rotating frame or (at least approximately) inertial frame
  logical :: UseRotatingFrame = .false. 

  ! Transformation from HGC to HGI systems can be done in a simulation
  logical :: DoTransformToHgi = .false.

  !\
  ! Variables for debugging. 
  !/

  ! Shall we be strict about errors in the input parameter file
  logical :: UseStrict=.true.

  ! Verbosity level (0, 1, 10, 100)
  integer :: lVerbose = 1

  ! A space separated list of words, typically names of subroutines.
  character (len=100) :: test_string=''

  ! Location for test
  integer :: iTest=1, jTest=1, kTest=1, BLKtest=1, PROCtest=0, ITERtest=-1
  integer :: VARtest=1, DIMtest=1
  real    :: xTest=0.0, yTest=0.0, zTest=0.0, tTest=0.0
  real    :: XyzTestCell_D(3)=0.0
  logical :: UseTestCell=.false., coord_test=.false.

  ! Debug logicals
  logical :: okdebug=.false., ShowGhostCells=.true.

  !\
  ! Time and timing variables
  !/
  real :: Time_Simulation = 0.0

  ! This is the same default value as in the SWMF
  integer, dimension(7) :: iStartTime_I = (/2000,3,21,10,45,0,0/)
  real(Real8_)          :: StartTime

  ! Timing variables
  logical:: UseTiming = .true.
  logical:: UseTimingAll = .false.
  integer:: iUnitTiming = 6
  character(len=30):: NameTimingFile
  integer:: dn_timing = -2

  !\
  ! Stopping conditions. These variables are only used in stand alone mode.
  !/
  real    :: t_Max = -1.0, cputime_max = -1.0
  integer :: nIter = -1
  logical :: Check_Stopfile = .true.
  logical :: IsLastRead = .false.

  !\
  ! Controling the use of the features implemented in user files
  !/
  logical:: UseUserInnerBcs          = .false.
  logical:: UseUserSource            = .false.
  logical:: UseUserPerturbation      = .false.
  logical:: UseUserOuterBcs          = .false.
  logical:: UseUserICs               = .false.
  logical:: UseUserSpecifyRefinement = .false.
  logical:: UseUserLogFiles          = .false.
  logical:: UseUserWritePlot         = .false.
  logical:: UseUserAMR               = .false.
  logical:: UseUserEchoInput         = .false.
  logical:: UseUserB0                = .false.
  logical:: UseUserInitSession       = .false.
  logical:: UseUserUpdateStates      = .false.

  !\
  ! For face formulation for outer boundary conditions, by setting
  ! DoFixOuterBoundary to .true. one can achive the same level of
  ! refinement across the outer boundary. 
  !/
  logical:: DoFixOuterBoundary       = .false.  

  !\
  ! For non-spherical geometry an extra boundary can be set, with
  ! or without fixing the refinement level across this boundary.
  ! With spherical geometry this structure is used to keep the 
  ! constant refinement level around the pole and to flag the blocks
  ! intersecting the pole.
  !/
  logical:: UseExtraBoundary         = .false.
  logical:: DoFixExtraBoundaryOrPole = .false.

  !\
  ! Number of true cells locally and globally
  !/
  integer :: nTrueCells, nTrueCellsALL

  !\
  ! Logical controlling the use of the laser heating.
  !/
  logical :: UseLaserHeating = .false.

end module ModMain
