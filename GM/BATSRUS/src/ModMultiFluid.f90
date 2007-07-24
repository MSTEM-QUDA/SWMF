module ModMultiFluid

  use ModVarIndexes

  implicit none
  save

  integer :: iFluid = 1
  integer ::                          &
       iRho   = Rho_,                 &
       iRhoUx = RhoUx_, iUx = RhoUx_, &
       iRhoUy = RhoUy_, iUy = RhoUy_, &
       iRhoUz = RhoUz_, iUz = RhoUz_, &
       iP     = P_,                   &
       iEnergy= nVar+1
  character (len=20) :: NameFluid = '', TypeFluid='ion'

  integer, parameter :: iRhoIon_I(nIonFluid)   = iRho_I(1:nIonFluid)
  integer, parameter :: iRhoUxIon_I(nIonFluid) = iRhoUx_I(1:nIonFluid)
  integer, parameter :: iRhoUyIon_I(nIonFluid) = iRhoUy_I(1:nIonFluid)
  integer, parameter :: iRhoUzIon_I(nIonFluid) = iRhoUz_I(1:nIonFluid)
  integer, parameter :: iUxIon_I(nIonFluid)    = iRhoUx_I(1:nIonFluid)
  integer, parameter :: iUyIon_I(nIonFluid)    = iRhoUy_I(1:nIonFluid)
  integer, parameter :: iUzIon_I(nIonFluid)    = iRhoUz_I(1:nIonFluid)
  integer, parameter :: iPIon_I(nIonFluid)     = iP_I(1:nIonFluid)

contains

  subroutine select_fluid
    integer :: i

    iRho   = iRho_I(iFluid)
    iRhoUx = iRhoUx_I(iFluid)
    iRhoUy = iRhoUy_I(iFluid)
    iRhoUz = iRhoUz_I(iFluid)
    iP     = iP_I(iFluid)

    iEnergy= nVar + iFluid

    iUx    = iRhoUx
    iUy    = iRhoUy
    iUz    = iRhoUz

    NameFluid = NameFluid_I(iFluid)
    TypeFluid = TypeFluid_I(iFluid)

  end subroutine select_fluid
  !============================================================
  subroutine extract_fluid_name(String)

    ! Find fluid name in string, remove it from string
    ! and set iFluid to the corresponding fluid index

    use ModUtilities, ONLY: lower_case


    character(len=*), intent(inout) :: String

    integer :: i, l
    character (len=10) :: NameFluid
    !----------------------------------------------------------
    
    ! Assume fluid 1 as the default
    iFluid = 1              

    ! Check if the string starts with a fluid name
    do i = 1, nFluid
       NameFluid = NameFluid_I(i)
       call lower_case(NameFluid)
       l = len_trim(NameFluid)
       if(String(1:l) == NameFluid)then
          ! Found fluid name, remove it from s
          iFluid = i
          String = String(l+1:len(String))
          EXIT
       end if
    end do
    call select_fluid

  end subroutine extract_fluid_name

end module ModMultiFluid
