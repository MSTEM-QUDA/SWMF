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
  use CON_router, ONLY: IndexPtrType, WeightPtrType
  use ModAdvance, ONLY: State_VGB,rho_,rhoUx_,rhoUz_,Bx_,Bz_,P_,&
       B0_DGB
  use ModPhysics, ONLY: Si2No_V, UnitRho_, UnitRhoU_, UnitP_, UnitB_

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
  integer:: i, j, k, iBlock

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
  
  State_V(BuffRho_)              = StateSI_V(BuffRho_) *Si2No_V(UnitRho_)
  State_V(BuffRhoUx_:BuffRhoUz_) = StateSI_V(BuffRhoUx_:BuffRhoUz_) &
       *Si2No_V(UnitRhoU_)
  State_V(BuffBx_:BuffBz_)       = StateSI_V(BuffBx_:BuffBz_)* Si2No_V(UnitB_)
  State_V(BuffP_)                = StateSI_V(BuffP_)         * Si2No_V(UnitP_)

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
     State_VGB(Bx_:Bz_,i,j,k,iBlock) = State_V(BuffBx_:BuffBz_) - &
          B0_DGB(:,i,j,k,iBlock)
     State_VGB(P_,i,j,k,iBlock)  = State_V(BuffP_)
  end if
end subroutine GM_put_from_ih
!==============================================================================
