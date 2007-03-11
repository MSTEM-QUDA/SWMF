!^CFG FILE DISSFLUX
!^CFG COPYRIGHT UM
module ModResistivity

  ! Resistivity related variables and methods

  use ModSize, ONLY: nI, nJ, nK, MaxBlock

  implicit none
  
  logical            :: UseResistivity=.false.
  character (len=30) :: TypeResistivity='none'
  real               :: Eta0Si, Eta0
  real               :: EtaPerpSpitzerSi
  real               :: CoulombLogarithm = 20.0
  real               :: Eta0AnomSi, Eta0Anom, EtaMaxAnomSi, EtaMaxAnom
  real               :: jCritAnomSi=1.0, jCritInv
  real               :: Si2NoEta

  real, allocatable :: Eta_GB(:,:,:,:)

  character(len=*), private, parameter :: NameMod = 'ModResistivity'

contains

  subroutine init_mod_resistivity

    use ModConst, ONLY: cLightSpeed, cElectronCharge, cElectronMass, cEps, &
         cBoltzmann, cTwoPi

    use ModPhysics, ONLY: Si2No_V, UnitX_, UnitT_, UnitJ_
    real :: UnitEta

    Si2NoEta = Si2No_V(UnitX_)**2/Si2No_V(UnitT_)

    Eta0       = Eta0Si       * Si2NoEta
    Eta0Anom   = Eta0AnomSi   * Si2NoEta
    EtaMaxAnom = EtaMaxAnomSi * Si2NoEta
    jCritInv   = 1.0/(jCritAnomSi  * Si2No_V(UnitJ_))

    ! Spitzer resistivity coefficient with Coulomb logarithm in SI units
    EtaPerpSpitzerSi = 0.5*sqrt(cElectronMass)    * &
         (cLightSpeed*cElectronCharge)**2/ &
         (3*cEps*(cTwoPi*cBoltzmann)**1.5) &
         *CoulombLogarithm

    if(.not.allocated(Eta_GB))then
       allocate(Eta_GB(-1:nI+2,-1:nJ+2,-1:nK+2,MaxBlock))

       if(TypeResistivity == 'constant')then
          Eta_GB = Eta0
       else
          Eta_GB = 0.0
       end if
    end if

  end subroutine init_mod_resistivity

  !===========================================================================

  subroutine spitzer_resistivity(iBlock, Eta_G)

    use ModConst,   ONLY: cProtonMass, cElectronCharge
    use ModPhysics, ONLY: No2Si_V, UnitB_, UnitRho_, UnitTemperature_
    use ModAdvance, ONLY: State_VGB, Rho_, P_, Bx_, By_, Bz_, &
         B0xCell_BLK, B0yCell_BLK, B0zCell_BLK

    ! Compute Spitzer-type, classical resistivity 

    integer, intent(in) :: iBlock
    real,    intent(out):: Eta_G(-1:nI+2, -1:nJ+2, -1:nK+2)

    real :: EtaSi, Coef
    integer :: i, j, k
    !-------------------------------------------------------------------------
    
    Coef =((cProtonMass/cElectronCharge)*No2Si_V(UnitB_)/No2Si_V(UnitRho_))**2

    do k=-1,nK+2; do j=-2, nJ+2; do i=-2, nI+2

       ! EtaSi = EtaPerpSpitzer/Te^1.5 in SI units
       EtaSi = EtaPerpSpitzerSi &
            / ( No2Si_V(UnitTemperature_)* &
            State_VGB(P_,i,j,k,iBlock)/State_VGB(Rho_,i,j,k,iBlock))**1.5

       ! Take into account the dependence on the B field:
       !    Eta' = Eta*(1 + [B*mp/(rho*e*Eta)]^2)
       EtaSi = EtaSi * (1.0 + Coef*( &
          (State_VGB(Bx_,i,j,k,iBlock)+B0xCell_BLK(i,j,k,iBlock))**2+&
          (State_VGB(By_,i,j,k,iBlock)+B0yCell_BLK(i,j,k,iBlock))**2+&
          (State_VGB(Bz_,i,j,k,iBlock)+B0zCell_BLK(i,j,k,iBlock))**2) &
          / (State_VGB(Rho_,i,j,k,iBlock)*EtaSi)**2)

       ! Normalize Eta_G
       Eta_G(i,j,k) = EtaSi*Si2NoEta
    end do; end do; end do

  end subroutine spitzer_resistivity

  !============================================================================

  subroutine anomalous_resistivity(iBlock, Eta_G)

    ! Compute current dependent anomalous resistivity

    integer, intent(in) :: iBlock
    real,    intent(out):: Eta_G(-1:nI+2, -1:nJ+2, -1:nK+2)

    real :: Current_D(3), AbsJ
    integer :: i, j, k
    !-------------------------------------------------------------------------

    ! Compute the magnitude of the current density |J|
    do k=0,nK+1; do j=0,nJ+1; do i=0,nI+1;

       call get_current(i,j,k,iBlock,Current_D)
       AbsJ = sqrt(sum(current_D**2))

       ! Compute the anomalous resistivity:: 
       ! Eta = Eta0 + Eta0Anom*(|J|/Jcrit-1) 
       
       Eta_G(i,j,k) = Eta0 + &
            min(EtaMaxAnom, max(0.0, Eta0Anom*(AbsJ*JcritInv - 1.0)))

    end do; end do; end do

  end subroutine anomalous_resistivity
 
end module ModResistivity

