!^CFG COPYRIGHT UM
subroutine SC_get_for_ih(&
     nPartial,iGetStart,Get,W,State_V,nVar)

  !USES:
  use SC_ModAdvance,ONLY: State_VGB, B0xCell_BLK, B0yCell_BLK, B0zCell_BLK, &
       rho_, rhoUx_, rhoUy_, rhoUz_, Bx_, By_, Bz_,P_


  use SC_ModPhysics,ONLY:UnitSI_rho,UnitSI_p,UnitSI_U,UnitSI_B,inv_g
  use SC_ModMain,ONLY:DoSendMHD, x_,y_,z_,nDim
  use SC_ModGeometry,ONLY:x_BLK,y_BLK,z_BLK
  use ModConst,ONLY: cMu 
 
  use CON_router

  implicit none

  !INPUT ARGUMENTS:
  integer,intent(in)::nPartial,iGetStart,nVar
  type(IndexPtrType),intent(in)::Get
  type(WeightPtrType),intent(in)::W
  real,dimension(nVar),intent(out)::State_V

  integer::iGet, i, j, k, iBlock
  real :: Weight,X_D(nDim),BernoulliIntegral,SumWeight,Rho,P,Xy

  character (len=*), parameter :: NameSub='SC_get_for_ih'
  !The meaning of state intdex in buffer and in model can be 
  !different. Below are the conventions for buffer:
  integer,parameter::&
       BuffRho_  =1,&
       BuffRhoUx_=2,&
       BuffRhoUz_=4,&
       BuffBx_   =5,&
       BuffBy_   =6,&
       BuffBz_   =7,&
       BuffP_    =8


  !----------------------------------------------------------
  if(DoSendMHD)then
     i      = Get%iCB_II(1,iGetStart)
     j      = Get%iCB_II(2,iGetStart)
     k      = Get%iCB_II(3,iGetStart)
     iBlock = Get%iCB_II(4,iGetStart)
     Weight = W%Weight_I(iGetStart)

     State_V(BuffRho_)          = &
          State_VGB(rho_,         i,j,k,iBlock) *Weight
     State_V(BuffRhoUx_:BuffRhoUz_) = &
          State_VGB(rhoUx_:rhoUz_,i,j,k,iBlock) *Weight
     State_V(BuffBx_)           = &
          (State_VGB(Bx_,          i,j,k,iBlock) + &
          B0xCell_BLK(i,j,k,iBlock))*Weight
     State_V(BuffBy_)           = &
          (State_VGB(By_,          i,j,k,iBlock) + &
          B0yCell_BLK(i,j,k,iBlock))*Weight
     State_V(BuffBz_)           = &
          (State_VGB(Bz_,          i,j,k,iBlock) + &
          B0zCell_BLK(i,j,k,iBlock))*Weight
     State_V(BuffP_)            = &
          State_VGB(P_,       i,j,k,iBlock) *Weight

     do iGet=iGetStart+1,iGetStart+nPartial-1
        i      = Get%iCB_II(1,iGet)
        j      = Get%iCB_II(2,iGet)
        k      = Get%iCB_II(3,iGet)
        iBlock = Get%iCB_II(4,iGet)
        Weight = W%Weight_I(iGet)
        State_V(BuffRho_)             =State_V(BuffRho_)             +&
             State_VGB(rho_,        i,j,k,iBlock) *Weight 
        State_V(BuffRhoUx_:BuffRhoUz_)=State_V(BuffRhoUx_:BuffRhoUz_)+&
             State_VGB(rhoUx_:rhoUz_,i,j,k,iBlock) *Weight
        State_V(BuffBx_)              =State_V(BuffBx_)              +&
             (State_VGB(Bx_,         i,j,k,iBlock) + &
             B0xCell_BLK(i,j,k,iBlock))*Weight
        State_V(BuffBy_)              =State_V(BuffBy_)              +&
             (State_VGB(By_,         i,j,k,iBlock) + &
             B0yCell_BLK(i,j,k,iBlock))*Weight
        State_V(BuffBz_)              =State_V(BuffBz_)              +&
             (State_VGB(Bz_,         i,j,k,iBlock) + &
             B0zCell_BLK(i,j,k,iBlock))*Weight
        State_V(BuffP_)               =State_V(BuffP_)               +&
             State_VGB(P_,      i,j,k,iBlock) *Weight
     end do


     ! Convert to SI units
     State_V(BuffRho_)             = State_V(BuffRho_)     *UnitSI_rho
     State_V(BuffRhoUx_:BuffRhoUz_)= &
          State_V(BuffRhoUx_:BuffRhoUz_)*        (UnitSI_rho*UnitSI_U)
     State_V(BuffBx_:BuffBz_)      = State_V(BuffBx_:BuffBz_)*UnitSI_B
     State_V(BuffP_)               = State_V(BuffP_)         *UnitSI_p
  else
     i      = Get%iCB_II(1,iGetStart)
     j      = Get%iCB_II(2,iGetStart)
     k      = Get%iCB_II(3,iGetStart)
     iBlock = Get%iCB_II(4,iGetStart)
     Weight = W%Weight_I(iGetStart)
     X_D(x_)=x_BLK(i,j,k,iBlock)*Weight
     X_D(y_)=y_BLK(i,j,k,iBlock)*Weight
     X_D(z_)=z_BLK(i,j,k,iBlock)*Weight
     SumWeight=Weight


     do iGet=iGetStart+1,iGetStart+nPartial-1
        i      = Get%iCB_II(1,iGet)
        j      = Get%iCB_II(2,iGet)
        k      = Get%iCB_II(3,iGet)
        iBlock = Get%iCB_II(4,iGet)
        Weight = W%Weight_I(iGet)
        X_D(x_)= X_D(x_)+x_BLK(i,j,k,iBlock)*Weight
        X_D(y_)= X_D(y_)+y_BLK(i,j,k,iBlock)*Weight
        X_D(z_)= X_D(z_)+z_BLK(i,j,k,iBlock)*Weight
        SumWeight=SumWeight+Weight
     end do
     X_D=X_D/SumWeight   !This is a weighted radius vector of the point,at 
                         !which we take the solar wind parameters
   
     call SC_get_magnetogram_field(X_D(x_),X_D(y_),X_D(z_),&
          State_V(BuffBx_:BuffBz_)) !Magnetogram field
     !Transfrom from Gauss to Tesla
     State_V(BuffBx_:BuffBz_)= State_V(BuffBx_:BuffBz_)/(cE1*cE3)
     !Remain only radial component of the field:
     State_V(BuffBx_:BuffBz_)=X_D*sum(State_V(BuffBx_:BuffBz_)*X_D)/sum(X_D**2)

     !\Get atmosphere 
     !/parameters.Transform to SI,

     State_V(BuffRho_)=cOne/sum(X_D**2)
     State_V(BuffP_) = State_V(BuffRho_)*inv_g
     State_V(BuffRho_) = State_V(BuffRho_)*UnitSI_rho
     State_V(BuffP_  ) = State_V(BuffP_)  *UnitSI_p


     call SC_get_bernoulli_integral(X_D(x_),X_D(y_),X_D(z_),'WSA',&
          BernoulliIntegral)
    
     !Limit the velocity to have a subAlfvenic velocty everewhere
     ! BernoulliIntegral=min(BernoulliIntegral,&
     !      5.0*sqrt(sum(State_V(BuffBx_:BuffBz_)**2)/(cMu*State_V(BuffRho_))))

     !The possible choice for the direction
     !of the solar wind speed:
     !Closer to that along the dipole field lines, rather than along radius:
     !Xy=sqrt(X_D(x_)**2+X_D(y_)**2)
     !X_D(z_)=sign(cOne,X_D(z_))*&
          !   max(abs(X_D(z_))-cTwo*Xy,-cHalf*abs(abs(X_D(z_))))
     X_D=X_D/sqrt(sum(X_D**2)) !Unity vector

     !Multiply by weight:
     State_V(BuffRho_) = State_V(BuffRho_)*SumWeight
     State_V(BuffP_  ) = State_V(BuffP_)  *SumWeight
     State_V(BuffBx_:BuffBz_)= State_V(BuffBx_:BuffBz_)*SumWeight
     
     State_V(BuffRhoUx_:BuffRhoUz_)= &
          State_V(BuffRho_)*BernoulliIntegral*X_D
  end if

end subroutine SC_get_for_ih
