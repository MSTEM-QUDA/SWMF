!^CFG COPYRIGHT UM
!^CFG FILE RAYTRACE
module ModRaytrace

  use ModSize
  use ModKind
  implicit none
  save

  ! Select between fast less accurate and slower but more accurate algorithms
  logical :: UseAccurateTrace = .false. 

  ! Named parameters for ray status (must be less than east_=1)
  integer, parameter :: &
       ray_iono_ = 0, &
       ray_block_=-1, &
       ray_open_ =-2, &
       ray_loop_ =-3, &
       ray_body_ =-4, &
       ray_out_  =-5

  ! Ray and rayface contain the x,y,z coordinates for the foot point of a given
  ! field line for both directions, eg. 
  ! ray(2,1,i,j,k,iBLK) is the y coord for direction 1

  ! ray is for cell centers; rayface is for block surfaces with 
  ! a -0.5,-0.5,-0.5 shift in block normalized coordinates

  real, dimension(3,2,nI+1,nJ+1,nK+1,nBLK) :: ray, rayface

  ! Stored face and cell indices of the 2 rays starting from a face of a block
  integer :: rayend_ind(3,2,nI+1,nJ+1,nK+1,nBLK)

  ! Stored weights for the 2 rays starting from a face of a block
  real    :: rayend_pos(4,2,nI+1,nJ+1,nK+1,nBLK)

  ! Radius where ray tracing with numerical B stops and 
  ! radius and radius squared of ionosphere

  real :: R_raytrace=1., R2_raytrace=1.

!!! These could be allocatable arrays ???
  
  ! Node interpolated magnetic field components without B0
  real, dimension(1:nI+1,1:nJ+1,1:nK+1,nBLK):: bb_x,bb_y,bb_z

  ! Total magnetic field with second order ghost cells
  real, dimension(3,-1:nI+2,-1:nJ+2,-1:nK+2,nBLK) :: Bxyz_DGB

  ! Prefer open and closed field lines in interpolation ?!
  logical :: UsePreferredInterpolation

  ! Testing
  logical :: oktest_ray=.false.

  real, parameter :: rIonosphere = 1.0, rIonosphere2 = rIonosphere**2
  real, parameter :: &
       CLOSEDRAY= -(rIonosphere + 0.05), &
       OPENRAY  = -(rIonosphere + 0.1), &
       BODYRAY  = -(rIonosphere + 0.2), &
       LOOPRAY  = -(rIonosphere + 0.3), &
       NORAY    = -(rIonosphere + 100.0), &
       OUTRAY   = -(rIonosphere + 200.0)

  real(Real8_) :: CpuTimeStartRay

  real         :: DtExchangeRay = 0.1

  integer      :: nOpen

  ! ----------- Variables for integrals along the ray -------------------
  ! True if the ray integrals are done
  logical :: DoIntegrate = .false.  

  ! Name indexes
  integer, parameter :: &
       InvB_=1, Z0x_=2, Z0y_=3, Z0b_=4, RhoInvB_=5, pInvB_=6, &
       xEnd_=7, yEnd_=8, zEnd_=9

  ! Number of integrals
  integer, parameter :: nRayIntegral = 9

  ! Flow variables to be integrated (rho and P) other than the magnetic field
  real, dimension(2,-1:nI+2,-1:nJ+2,-1:nK+2,nBLK) :: Extra_VGB

  ! Integrals for a local ray segment
  real :: RayIntegral_V(InvB_:pInvB_)

  ! Integrals added up for all the local ray segments
  ! The fist index corresponds to the variables (index 0 shows closed vs. open)
  ! The second and third indexes correspond to the latitude and longitude of
  ! the IM/RCM grid
  real, allocatable :: RayIntegral_VII(:,:,:)
  real, allocatable :: RayResult_VII(:,:,:)

contains

  !============================================================================

  subroutine xyz_to_latlon(Pos_D)

    use ModNumConst, ONLY: cTiny, cRadToDeg

    ! Convert xyz coordinates to latitude and longitude (in degrees)
    ! Put the latitude and longitude into the 1st and 2nd elements
    real, intent(inout) :: Pos_D(3)

    real :: x, y, z

    !-------------------------------------------------------------------------

    ! Check if this direction is closed or not
    if(Pos_D(1) > CLOSEDRAY)then

       ! Store input coordinates
       x = Pos_D(1); y = Pos_D(2); z = Pos_D(3)

       ! Make sure that asin will work, -1<= z <=1
       z = max(-1.0+cTiny, z)
       z = min( 1.0-cTiny, z)

       ! Calculate  -90 < latitude = asin(z)  <  90
       Pos_D(1) = cRadToDeg * asin(z)

       ! Calculate -180 < longitude = atan2(y,x) < 180
       if(abs(x) < cTiny .and. abs(y) < cTiny) x = 1.0
       Pos_D(2) = cRadToDeg * atan2(y,x)

       ! Get rid of negative longitude angles
       if(Pos_D(2) < 0.0) Pos_D(2) = Pos_D(2) + 360.0

    else
       ! Impossible values
       Pos_D(1) = -100.
       Pos_D(2) = -200.
    endif

  end subroutine xyz_to_latlon

  !============================================================================

  subroutine xyz_to_latlonstatus(Ray_DI)

    real, intent(inout) :: Ray_DI(3,2)

    integer :: iRay
    !-------------------------------------------------------------------------

    ! Convert 1st and 2nd elements into latitude and longitude
    do iRay=1,2
       call xyz_to_latlon(Ray_DI(:,iRay))
    end do

    ! Convert 3rd element into a status variable

    if(Ray_DI(3,1)>CLOSEDRAY .and. Ray_DI(3,2)>CLOSEDRAY)then
       Ray_DI(3,1)=3.      ! Fully closed
    elseif(Ray_DI(3,1)>CLOSEDRAY .and. Ray_DI(3,2)==OPENRAY)then
       Ray_DI(3,1)=2.      ! Half closed in positive direction
    elseif(Ray_DI(3,2)>CLOSEDRAY .and. Ray_DI(3,1)==OPENRAY)then
       Ray_DI(3,1)=1.      ! Half closed in negative direction
    elseif(Ray_DI(3,1)==OPENRAY .and. Ray_DI(3,2)==OPENRAY) then
       Ray_DI(3,1)=0.      ! Fully open
    elseif(Ray_DI(3,1)==BODYRAY)then
       Ray_DI(3,1)=-1.     ! Cells inside body
    elseif(Ray_DI(3,1)==LOOPRAY .and.  Ray_DI(3,2)==LOOPRAY) then
       Ray_DI(3,1)=-2.     ! Loop ray within block
    else
       Ray_DI(3,1)=-3.     ! Strange status
    end if

  end subroutine xyz_to_latlonstatus

  !============================================================================

end module ModRaytrace
