!  Copyright (C) 2002 Regents of the University of Michigan, portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
module ModVarIndexes

  use ModSingleFluid
  use ModExtraVariables,        &
       Redefine1 => Hyp_,       &
       Redefine2 => nWave,      &
       Redefine3 => WaveFirst_, &
       Redefine4 => WaveLast_,  &
       Redefine5 => Pe_

  implicit none

  save

  ! This equation module contains the standard MHD equations plus
  ! extra wave energies
  character (len=*), parameter :: &
       NameEquation ='MHD + Alfven waves + electron pressure + hyperbolic divB'

  ! loop variable over spectrum
  integer, private :: iWave

  ! Number of frequency bins in spectrum
  integer, parameter :: nWave = 2
  integer, parameter :: nVar = 10 + nWave
  
  ! Named indexes for State_VGB and other variables
  ! These indexes should go subsequently, from 1 to nVar+1.
  ! The energy is handled as an extra variable, so that we can use
  ! both conservative and non-conservative scheme and switch between them.
  integer, parameter :: &
       Rho_       = 1,  &
       RhoUx_     = 2,  &
       RhoUy_     = 3,  &
       RhoUz_     = 4,  &
       Bx_        = 5,  &
       By_        = 6,  &
       Bz_        = 7,  &
       Hyp_       = 8,  &
       WaveFirst_ = 9,  &
       WaveLast_  = WaveFirst_+nWave-1, &
       Pe_        = WaveLast_ + 1,      &
       p_         = nVar, &
       Energy_    = nVar+1  

  ! This allows to calculate rhoUx_ as rhoU_+x_ and so on.
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
       0.0, & ! RhoUx_
       0.0, & ! RhoUy_
       0.0, & ! RhoUz_
       0.0, & ! Bx_
       0.0, & ! By_
       0.0, & ! Bz_
       0.0, & ! Hyp_
       (1.0, iWave=WaveFirst_,WaveLast_), & 
       1.0, & ! Pe_
       1.0, & ! p_
       1.0 /) ! Energy_ 
 
  ! The names of the variables used in i/o
  character(len=3) :: NameVar_V(nVar+1) = (/ &
       'Rho', & ! Rho_
       'Mx ', & ! RhoUx_
       'My ', & ! RhoUy_
       'Mz ', & ! RhoUz_
       'Bx ', & ! Bx_
       'By ', & ! By_
       'Bz ', & ! Bz_
       'Hyp', & ! Hyp_
       ('I??', iWave=1,nWave), & ! Waves to be reset
       'Pe ', & ! Pe_
       'p  ', & ! p_
       'e  '/)  ! Energy_        
  
  ! The space separated list of nVar conservative variables for plotting
  character(len=*), parameter :: NameConservativeVar = &
       'rho mx my mz bx by bz hyp ew pe e'
 
  ! The space separated list of nVar primitive variables for plotting
  character(len=*), parameter :: NamePrimitiveVar = &
       'rho ux uy uz bx by bz hyp I(02) pe p'

  ! The space separated list of nVar primitive variables for TECplot output
  character(len=*), parameter :: NamePrimitiveVarTec = &
       '"`r", "U_x", "U_y", "U_z", "B_x", "B_y", "B_z", "Hyp", ' // &
       '"E_w", "p_e", "p"'

  ! Names of the user units for IDL and TECPlot output
  character(len=20) :: &
       NameUnitUserIdl_V(nVar+1) = '', NameUnitUserTec_V(nVar+1) = ''

  ! The user defined units for the variables
  real :: UnitUser_V(nVar+1) = 1.0

  ! Primitive variable names
  integer, parameter :: U_ = RhoU_, Ux_ = RhoUx_, Uy_ = RhoUy_, Uz_ = RhoUz_

  ! No scalars
  integer, parameter :: ScalarFirst_ = 2, ScalarLast_ = 1

  ! There are no multi-species
  logical, parameter :: UseMultiSpecies = .false.

  ! Declare the following variables to satisfy the compiler
  integer, parameter :: SpeciesFirst_ = 1, SpeciesLast_ = 1
  real               :: MassSpecies_V(SpeciesFirst_:SpeciesLast_)

contains

  subroutine init_mod_equation

    call init_mhd_variables

  end subroutine init_mod_equation

end module ModVarIndexes


