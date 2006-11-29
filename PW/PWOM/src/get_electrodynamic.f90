!******************************************************************************
!  This subroutine gets the electrodynamic parameters, and gets the convection
!  velocity. 
!******************************************************************************
subroutine PW_get_electrodynamic

  use ModIoUnit, ONLY: UnitTmp_
  use ModPWOM
  use ModNumConst, ONLY:cDegToRad
  implicit none
  !---------------------------------------------------------------------------
  open(UnitTmp_, FILE=NamePhiNorth)  

  if (IsStandAlone) then
     call allocate_ie_variables(257, 65)
     do iPhi=1,nPhi
        do iTheta=1,nTheta
           read(unit=UnitTmp_,fmt='(6(1PE13.5))') &
               Theta_G(iPhi,iTheta),Phi_G(iPhi,iTheta),SigmaH_G(iPhi,iTheta),&
               SigmaP_G(iPhi,iTheta),Jr_G(iPhi,iTheta),Potential_G(iPhi,iTheta)
           
        enddo
     enddo
  endif
  close(UnitTmp_)


!******************************************************************************
!  Change angles to radians
!******************************************************************************
  Theta_G(:,:) = Theta_G(:,:)*cDegToRad
  Phi_G  (:,:) = Phi_G  (:,:)*cDegToRad

!******************************************************************************
!  Convert potential from kilovolts to Volts
!******************************************************************************
  Potential_G(:,:) = Potential_G(:,:)*1.0e3
!******************************************************************************
!  Calc Bfield components
!******************************************************************************
  rPlanet        = 6378000.0
  rLowerBoundary = rPlanet+110.0e3
  MagMoment      = 7.84e15
  Bcoef          = MagMoment/(rLowerBoundary)**3 
  do iPhi=1,nPhi
     do iTheta=1,nTheta
        Br_G(iPhi,iTheta)     = -Bcoef*2.0*sin(Theta_G(iPhi,iTheta))
        Btheta_G(iPhi,iTheta) = Bcoef*cos(Theta_G(iPhi,iTheta))
     enddo
  enddo
  
  BmagnitudeSquared_G(:,:) = Br_G(:,:)**2 + Btheta_G(:,:)**2
!******************************************************************************
!  Fill Ghost cells
!******************************************************************************
  Theta_G    (nPhi+1,:) = Theta_G    (2,:) 
  Phi_G      (nPhi+1,:) = Phi_G      (2,:)
  SigmaH_G   (nPhi+1,:) = SigmaH_G   (2,:)
  SigmaP_G   (nPhi+1,:) = SigmaP_G   (2,:) 
  Jr_G       (nPhi+1,:) = Jr_G       (2,:)
  Potential_G(nPhi+1,:) = Potential_G(2,:)

  Theta_G    (0,:) = Theta_G    (nPhi-1,:) 
  Phi_G      (0,:) = Phi_G      (nPhi-1,:)
  SigmaH_G   (0,:) = SigmaH_G   (nPhi-1,:)
  SigmaP_G   (0,:) = SigmaP_G   (nPhi-1,:) 
  Jr_G       (0,:) = Jr_G       (nPhi-1,:)
  Potential_G(0,:) = Potential_G(nPhi-1,:)

  Theta_G    (:,nTheta+1) = Theta_G    (:,nTheta) 
  Phi_G      (:,nTheta+1) = Phi_G      (:,nTheta)
  SigmaH_G   (:,nTheta+1) = SigmaH_G   (:,nTheta)
  SigmaP_G   (:,nTheta+1) = SigmaP_G   (:,nTheta) 
  Jr_G       (:,nTheta+1) = Jr_G       (:,nTheta)
  Potential_G(:,nTheta+1) = Potential_G(:,nTheta)

  do iPhi=1,nPhi
     Theta_G    (iPhi,0) = Theta_G    (mod(iPhi+floor(nPhi/2.0),nPhi-1),2) 
     Phi_G      (iPhi,0) = Phi_G      (mod(iPhi+floor(nPhi/2.0),nPhi-1),2)
     SigmaH_G   (iPhi,0) = SigmaH_G   (mod(iPhi+floor(nPhi/2.0),nPhi-1),2)
     SigmaP_G   (iPhi,0) = SigmaP_G   (mod(iPhi+floor(nPhi/2.0),nPhi-1),2) 
     Jr_G       (iPhi,0) = Jr_G       (mod(iPhi+floor(nPhi/2.0),nPhi-1),2)
     Potential_G(iPhi,0) = Potential_G(mod(iPhi+floor(nPhi/2.0),nPhi-1),2)
  enddo



!******************************************************************************
!  Calc electric field from E=-grad Potential
!******************************************************************************
 
  
  do iPhi=1,nPhi
     do iTheta=1,nTheta
        Etheta(iPhi,iTheta) = &
             (Potential_G(iPhi,iTheta)-Potential_G(iPhi,iTheta+1))&
             /((rLowerBoundary)*Dtheta)
        if (iTheta == 1) then
           Ephi(iPhi,iTheta) = 0.0
        else
           Ephi(iPhi,iTheta)   = &
                (Potential_G(iPhi-1,iTheta)-Potential_G(iPhi+1,iTheta))&
                / ((rLowerBoundary)*2.0*Dphi  &
                * sin(Theta_G(iPhi,iTheta)))
        endif
    enddo
  enddo
  Er(:,:) = 0.0
!******************************************************************************
!  Calc VelocityExB drift from E and B
!******************************************************************************
  

  do iPhi=1,nPhi
     do iTheta=1,nTheta
        VelocityExBtheta(iPhi,iTheta) = &
             (Ephi(iPhi,iTheta)*Br_G(iPhi,iTheta)) &
             / BmagnitudeSquared_G(iPhi,iTheta)
        
        VelocityExBphi(iPhi,iTheta)   = &
             (-Etheta(iPhi,iTheta)*Br_G(iPhi,iTheta)) &
             / BmagnitudeSquared_G(iPhi,iTheta)
        
        VelocityExBr(iPhi,iTheta)     = &
             (-Ephi(iPhi,iTheta)*Btheta_G(iPhi,iTheta)) &
             / BmagnitudeSquared_G(iPhi,iTheta)


     enddo
  enddo
  VelocityExBtheta(:,1) = VelocityExBtheta(:,2)
  VelocityExBphi  (:,1) = VelocityExBphi  (:,2)
  
  if (.not.IsMoveFluxTube) Then 
     VelocityExBtheta(:,:) = 0.0
     VelocityExBPhi  (:,:) = 0.0
     VelocityExBr    (:,:) = 0.0
  endif

  if (.not.IsUseJr) Then 
     Jr_G(:,:) = 0.0
  endif


end subroutine PW_get_electrodynamic
