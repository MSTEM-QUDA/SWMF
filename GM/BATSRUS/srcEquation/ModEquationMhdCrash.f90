!  Copyright (C) 2002 Regents of the University of Michigan, portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
module ModVarIndexes
  use ModSingleFluid
  use ModExtraVariables, &
       Redefine1  => Erad_, &
       Redefine2  => nWave, &
       Redefine3  => WaveFirst_, &
       Redefine4  => WaveLast_, &
       Redefine5  => ExtraEint_, &
       Redefine6  => Pe_, &
       Redefine7  => nMaterial, &
       Redefine8  => MaterialFirst_, &
       Redefine9  => MaterialLast_, &
       Redefine10 => Hyp_

  implicit none

  save

  ! This equation module contains the CRASH equations with magnetic field.
  ! An extra scalar variable to carry the div B away (hyperbolic cleaning)
  character (len=*), parameter :: &
       NameEquation='MHD+Ionization+Levels+Electron energy+Radiation'

  ! loop variable for implied do-loop over material levels and spectrum
  integer, private :: iMaterial, iWave

  ! Number of material levels
  integer, parameter :: nMaterial = 3
  ! Number of wave bins in spectrum
  integer, parameter :: nWave = 1

  integer, parameter :: nVar = 11 + nMaterial + nWave

  ! Named indexes for State_VGB and other variables
  ! These indexes should go subsequently, from 1 to nVar+nFluid.
  ! The energies are handled as an extra variable, so that we can use
  ! both conservative and non-conservative scheme and switch between them.
  integer, parameter :: &
       Rho_           = 1,                          &
       RhoUx_         = 2, Ux_ = 2,                 &
       RhoUy_         = 3, Uy_ = 3,                 &
       RhoUz_         = 4, Uz_ = 4,                 &
       Bx_            = 5,                          &
       By_            = 6,                          &
       Bz_            = 7,                          &
       Hyp_           = 8,                          &
       MaterialFirst_ = 9,                          &
       MaterialLast_  = MaterialFirst_+nMaterial-1, &
       Pe_            = MaterialLast_+1,            &
       WaveFirst_     = Pe_+1,                      &
       WaveLast_      = WaveFirst_+nWave-1,         &
       ExtraEint_     = WaveLast_+1,                &
       p_             = nVar,                       &
       Energy_        = nVar+1

  ! This is for backward compatibility with single group radiation
  integer, parameter :: Erad_ = WaveFirst_

  ! This allows to calculate RhoUx_ as RhoU_+x_ and so on.
  integer, parameter :: U_ = Ux_ - 1, RhoU_ = RhoUx_-1, B_ = Bx_-1

  ! The default values for the state variables:
  ! Variables which are physically positive should be set to 1,
  ! variables that can be positive or negative should be set to 0:
  real, parameter :: DefaultState_V(nVar+nFluid) = (/ & 
       1.0, & ! Rho_
       0.0, & ! RhoUx_
       0.0, & ! RhoUy_
       0.0, & ! RhoUz_
       0.0, & ! Bx_
       0.0, & ! By_
       0.0, & ! Bz_
       0.0, & ! Hyp_
       (0.0, iMaterial=MaterialFirst_,MaterialLast_), &
       1.0, & ! Pe_
       (1.0, iWave=WaveFirst_,WaveLast_), &
       0.0, & ! ExtraEint_
       1.0, & ! p_
       1.0 /) ! Energy_

  ! The names of the variables used in i/o
  character(len=4) :: NameVar_V(nVar+nFluid) = (/ &
       'Rho ', & ! Rho_
       'Mx  ', & ! RhoUx_
       'My  ', & ! RhoUy_
       'Mz  ', & ! RhoUz_
       'Bx  ', & ! Bx_
       'By  ', & ! By_
       'Bz  ', & ! Bz_
       'Hyp ', & ! Hyp_
       ('M?  ', iMaterial=MaterialFirst_,MaterialLast_), &
       'Pe  ', & ! Pe_
       ('I?? ', iWave=WaveFirst_,WaveLast_), &
       'EInt', & ! ExtraEint_
       'P   ', & ! p_
       'E   '/)  ! Energy_

  ! The space separated list of nVar conservative variables for plotting
  character(len=*), parameter :: NameConservativeVar = &
       'Rho Mx My Mz Bx By Bz Hyp Pe Ew EInt E'

  ! The space separated list of nVar primitive variables for plotting
  character(len=*), parameter :: NamePrimitiveVar = &
       'Rho Ux Uy Uz Bx By Bz Hyp M(3) Pe I(01) EInt P'

  ! The space separated list of nVar primitive variables for TECplot output
  character(len=*), parameter :: NamePrimitiveVarTec = &
       '"`r", "U_x", "U_y", "U_z", "B_x", "B_y", "B_z", "Hyp", "Pe", "I", "EInt", "p"'

  ! Names of the user units for IDL and TECPlot output
  character(len=20) :: &
       NameUnitUserIdl_V(nVar+nFluid) = '', NameUnitUserTec_V(nVar+nFluid) = ''

  ! The user defined units for the variables
  real :: UnitUser_V(nVar+nFluid) = 1.0

  ! Advected are the three level sets and the extra internal energy
  ! Note that the variable Hyp is not advected with velocity
  integer, parameter :: ScalarFirst_ = MaterialFirst_, ScalarLast_ = ExtraEint_

  ! There are no multi-species
  logical, parameter :: UseMultiSpecies = .false.

  ! Declare the following variables to satisfy the compiler
  integer, parameter :: SpeciesFirst_ = 1, SpeciesLast_ = 1
  real               :: MassSpecies_V(SpeciesFirst_:SpeciesLast_)
  integer, parameter :: iRho_I(nFluid)   = (/Rho_/)
  integer, parameter :: iRhoUx_I(nFluid) = (/RhoUx_/)
  integer, parameter :: iRhoUy_I(nFluid) = (/RhoUy_/)
  integer, parameter :: iRhoUz_I(nFluid) = (/RhoUz_/)
  integer, parameter :: iP_I(nFluid)     = (/p_/)

contains

  subroutine init_mod_equation

    call init_mhd_variables

  end subroutine init_mod_equation

end module ModVarIndexes
