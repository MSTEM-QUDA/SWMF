!BOP
!MODULE: ModInitGridStorage - set the number of grids and optimize the memory to store them
!INTERFACE:
module ModInitGridStorage
  !USES:
  use CON_world, ONLY: MaxComp
  use CON_comp_param
  use CON_domain_decomposition, ONLY: DDPointerType, DomainDecompositionType
  implicit none
  !EOP
  integer,parameter:: MaxGrid = MaxComp+3
  type(DomainDecompositionType),private,save,target::&
       GmGrid,IhGrid,UaGrid,IeGrid,ImGrid,PwGrid,RbGrid,SpGrid,ScGrid,PsGrid
contains
  !BOP
  !REVISION HISTORY:
  !09SEP03              I.Sokolov<igorsok@umich.edu - initial prototype/code
  !12SEP03              version for any operating system
  !16JAN05              G.Toth removed the obsolete GmIe_grid
  !BOP
  !IROUTINE: init_grid_storage - initialize a storage for component grids
  !INTERFACE:
  subroutine init_grid_storage(DD_I,GridID_)
    !INPUT ARGUMENTS:
    integer,intent(in)::GridID_
    !INPUT/OUTPUT ARGUMENTS:
    type(DDPointerType), dimension(MaxGrid), intent(inout) :: DD_I
    !DESCRIPTION: 
    ! information for the global grids is stored at each of the PEs so it is
    ! important to reduce the memory requirements. This short procedure 
    ! describes how the memory is allocated for the domain decomposition 
    ! structure. This solution satisfies the most picky SGI compiler, 
    ! but requires to add manually an identifier for the domain 
    ! decomposition while addung a new component to the framework. 
    !EOP
    select case(GridID_)
    case(GM_)
       DD_I(GridID_)%Ptr=>GmGrid
    case(IE_)
       DD_I(GridID_)%Ptr=>IeGrid
    case(IM_)
       DD_I(GridID_)%Ptr=>ImGrid
    case(IH_)
       DD_I(GridID_)%Ptr=>IhGrid
    case(PW_)
       DD_I(GridID_)%Ptr=>PwGrid
    case(RB_)
       DD_I(GridID_)%Ptr=>RbGrid
    case(SP_)
       DD_I(GridID_)%Ptr=>SpGrid
    case(SC_)
       DD_I(GridID_)%Ptr=>ScGrid
    case(UA_)
       DD_I(GridID_)%Ptr=>UaGrid
    case(PS_)
       DD_I(GridID_)%Ptr=>PsGrid
    case default
       write(*,*)'ERROR in ModInitGridStorage: GridID = ',GridID_
       call CON_stop('ERRORin ModInitGridStorage: not implemented grid ID')
    end select
  end subroutine init_grid_storage
end module ModInitGridStorage
