!^CFG COPYRIGHT UM
!
!BOP
!
!MODULE: CON_physics - provides methods for physics accessible by components
!INTERFACE:
module CON_physics

  !USES:

  use CON_axes            ! Part of share/Library
  use CON_planet          ! Part of share/Library
  use CON_planet_field    ! Part of share/Library
  use CON_time            ! Part of CON/Library

  implicit none

  private ! except
  
  !PUBLIC DATA MEMBERS:
  public :: lNamePlanet      ! length of NamePlanet string
  public :: lTypeBField      ! length of TypeBField string

  !PUBLIC MEMBER FUNCTIONS:
  public :: get_axes         ! get information about (coordinate) axes
  public :: transform_matrix ! return transformation matrix between two systems
  public :: get_planet       ! get planet related parameters
  public :: get_planet_field ! get planet field at a point and time
  public :: map_planet_field ! map planet field to some radius
  public :: time_real_to_int ! transform double precision seconds into date
  public :: time_int_to_real ! transform date into double precision seconds
  public :: n_day_of_year    ! return day of year calculated from date
  public :: get_time         ! get time related parameters

  !REVISION HISTORY:
  ! 14Aug03 - Gabor Toth <gtoth@umich.edu> - initial prototype/prolog/code
  ! 26Mar04 - Gabor Toth removed get_physics, access get_time, get_planet
  !EOP


end module CON_physics
