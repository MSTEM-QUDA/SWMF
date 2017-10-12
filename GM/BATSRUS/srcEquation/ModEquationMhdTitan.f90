!  Copyright (C) 2002 Regents of the University of Michigan
!  portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
module ModVarIndexes

  use ModSingleFluid
  use ModExtraVariables, &
       Redefine1 => SpeciesFirst_, &
       Redefine2 => SpeciesLast_,  &
       Redefine3 => MassSpecies_V

  implicit none

  save

  ! This equation module contains the MHD equations with species for Mars
  character (len=*), parameter :: NameEquation='Titan MHD'

  ! Number of variables without energy:
  integer, parameter :: nVar = 15  !8 + 7 ion species

  ! Named indexes for State_VGB and other variables
  ! These indexes should go subsequently, from 1 to nVar+1.
  ! The energy is handled as an extra variable, so that we can use
  ! both conservative and non-conservative scheme and switch between them.
  integer, parameter :: &
       Rho_     = 1,    &
       RhoLp_   = 2,    &
       RhoMp_   = 3,    &
       RhoH1p_  = 4,    &
       RhoH2p_  = 5,    &
       RhoMHCp_ = 6,    &
       RhoHHCp_ = 7,    &
       RhoHNIp_ = 8,    &
       RhoUx_   = 9,    &
       RhoUy_   =10,    &
       RhoUz_   =11,    &
       Bx_      =12,    &
       By_      =13,    &
       Bz_      =14,    &
       p_       = nVar, &
       Energy_  = nVar+1

  ! This allows to calculate RhoUx_ as rhoU_+x_ and so on.
  integer, parameter :: RhoU_ = RhoUx_-1, B_ = Bx_-1

  ! These arrays are useful for multifluid
  integer, parameter :: iRho_I(nFluid)   = (/Rho_/)
  integer, parameter :: iRhoUx_I(nFluid) = (/RhoUx_/)
  integer, parameter :: iRhoUy_I(nFluid) = (/RhoUy_/)
  integer, parameter :: iRhoUz_I(nFluid) = (/RhoUz_/)
  integer, parameter :: iP_I(nFluid)     = (/p_/)

  ! The default values for the state variables:
  ! Variables which are physically positive should be set to 1,
  ! variables that can be positive or negative should be set to 0:
  real, parameter :: DefaultState_V(nVar+1) = (/ & 
       1.0, & ! Rho_
       1.0, & ! RhoLp_
       1.0, & ! RhoMp_
       1.0, & ! RhoH1p_
       1.0, & ! RhoH2p_
       1.0, & ! RhoMHCp_
       1.0, & ! RhoHHCp_
       1.0, & ! RhoHNIp_
       0.0, & ! RhoUx_
       0.0, & ! RhoUy_
       0.0, & ! RhoUz_
       0.0, & ! Bx_
       0.0, & ! By_
       0.0, & ! Bz_
       1.0, & ! p_
       1.0 /) ! Energy_

  ! The names of the variables used in i/o
  character(len=4) :: NameVar_V(nVar+1) = (/ &
       'Rho ', & ! Rho_
       'Lp  ', & ! RhoLp_
       'Mp  ', & ! RhoMp_
       'H1p ', & ! RhoH1p_
       'H2p ', & ! RhoH2p_
       'MHCp', & ! RhoMHCp_
       'HHCp', & ! RhoHHCp_
       'HNIp', & ! RhoHNIp_
       'Mx  ', & ! RhoUx_
       'My  ', & ! RhoUy_
       'Mz  ', & ! RhoUz_
       'Bx  ', & ! Bx_
       'By  ', & ! By_
       'Bz  ', & ! Bz_
       'p   ', & ! p_
       'e   ' /) ! Energy_


  ! Primitive variable names
  integer, parameter :: U_ = RhoU_, Ux_ = RhoUx_, Uy_ = RhoUy_, Uz_ = RhoUz_

  ! Scalars to be advected.
  integer, parameter :: ScalarFirst_ = RhoLp_, ScalarLast_ = RhoHNIp_

  ! Species
  integer, parameter :: SpeciesFirst_   = ScalarFirst_
  integer, parameter :: SpeciesLast_    = ScalarLast_

  ! Molecular mass of species H, O2, O, CO2 in AMU:
  real:: MassSpecies_V(SpeciesFirst_:SpeciesLast_) = &
       (/1.0,14.0,29.0,28.0,44.0,70.0,74.0/)

end module ModVarIndexes
