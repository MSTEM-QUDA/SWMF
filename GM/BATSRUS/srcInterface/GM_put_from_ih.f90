!==============================================================================
!BOP
!ROUTINE: GM_put_from_ih - tranfrom and put the data got from IH_
!INTERFACE:
subroutine GM_put_from_ih(nPartial,&
     iPutStart,&
     Put,& 
     Weight,&
     DoAdd,&
     StateSI_V,&
     nVar)
  !USES:
  use CON_coupler, ONLY: IndexPtrType, WeightPtrType
  use ModAdvance, ONLY: State_VGB,rho_,rhoUx_,rhoUy_,rhoUz_,Bx_,By_,Bz_,P_,&
       B0xCell_BLK, B0yCell_BLK, B0zCell_BLK

  use ModPhysics,ONLY:UnitSI_rho,UnitSI_p,UnitSI_U,UnitSI_B! nVarGm => nVar

  implicit none

  !INPUT ARGUMENTS:
  integer,intent(in)::nPartial,iPutStart,nVar
  type(IndexPtrType),intent(in)::Put
  type(WeightPtrType),intent(in)::Weight
  logical,intent(in)::DoAdd
  real,dimension(nVar),intent(in)::StateSI_V

  !REVISION HISTORY:
  !18JUL03     I.Sokolov <igorsok@umich.edu> - intial prototype/code
  !23AUG03                                     prolog
  !03SEP03     G.Toth    <gtoth@umich.edu>   - simplified
  !19JUL04     I.Sokolov <igorsok@umich.edu> - sophisticated back 
  !                  (this is what we refer to as a development)
  !EOP

  character (len=*), parameter :: NameSub='GM_put_from_ih.f90'

  real,dimension(nVar)::State_V
  integer::iPut, i, j, k, iBlock

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


  !-----------------------------------------------------------------------
  
  State_V(BuffRho_)              = StateSI_V(BuffRho_)     / UnitSI_rho
  State_V(BuffRhoUx_:BuffRhoUz_) = StateSI_V(BuffRhoUx_:BuffRhoUz_)&
                                   /(UnitSI_rho*UnitSI_U)
  State_V(BuffBx_:BuffBz_)       = StateSI_V(BuffBx_:BuffBz_)/ UnitSI_B
  State_V(BuffP_)                = StateSI_V(BuffP_)         / UnitSI_p

  i      = Put%iCB_II(1,iPutStart)
  j      = Put%iCB_II(2,iPutStart)
  k      = Put%iCB_II(3,iPutStart)
  iBlock = Put%iCB_II(4,iPutStart)

  if(DoAdd)then
     State_VGB(rho_,i,j,k,iBlock) = State_VGB(rho_,i,j,k,iBlock) + &
          State_V(BuffRho_)
     State_VGB(rhoUx_:rhoUz_,i,j,k,iBlock) = &
          State_VGB(rhoUx_:rhoUz_,i,j,k,iBlock) + &
          State_V(BuffRhoUx_:BuffRhoUz_)
     State_VGB(Bx_:Bz_,i,j,k,iBlock) = &
          State_VGB(Bx_:Bz_,i,j,k,iBlock) + &
          State_V(BuffBx_:BuffBz_)
     State_VGB(P_,i,j,k,iBlock) = State_VGB(P_,i,j,k,iBlock) + &
          State_V(BuffP_)
     
  else
     State_VGB(rho_,i,j,k,iBlock)= State_V(BuffRho_)
     State_VGB(rhoUx_:rhoUz_,i,j,k,iBlock) =  State_V(BuffRhoUx_:BuffRhoUz_)
     State_VGB(Bx_,i,j,k,iBlock) = State_V(BuffBx_) - B0xCell_BLK(i,j,k,iBlock)
     State_VGB(By_,i,j,k,iBlock) = State_V(BuffBy_) - B0yCell_BLK(i,j,k,iBlock)
     State_VGB(Bz_,i,j,k,iBlock) = State_V(BuffBz_) - B0zCell_BLK(i,j,k,iBlock)
     State_VGB(P_,i,j,k,iBlock)  = State_V(BuffP_)
  end if
end subroutine GM_put_from_ih
!==============================================================================
