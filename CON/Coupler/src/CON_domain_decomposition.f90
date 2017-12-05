!  Copyright (C) 2002 Regents of the University of Michigan, portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
!
!QUOTE: \clearpage
!
!BOP
!
!QUOTE: \section{CON/Coupler: the SWMF Parallel Coupling Toolkit}
!
!MODULE: CON_domain_decomposition - for uniform or octree grids
!INTERFACE:
Module CON_domain_decomposition

  !DESCRIPTION:
  !The toolkit for coupling the different data sets within a      
  !single component code, or within a framework as it is now (see 
  !the date below) consists of: 
  !                                  
  !ModMpi (iclude for mpif90.h)
  !                                   
  !ModNumConst
  !                                                    
  !CON\_world
  !                                                                   
  !CON\_domain\_decomposition
  !                                     
  !CON\_grid\_descriptor
  !                                          
  !CON\_router
  !                                                    
  !CON\_global\_message\_pass                                     
  !
  !
  !This file presents the class of the domain decompositions which  
  !icludes both the uniformly spaced ones (uniformly spaced with  
  !respect to some generalized coordinates) and Octree or Quadric 
  !tree for adaptive block decompositions.                        
  !
  !
  !The methods include: allocation, initialization, broadcast,     
  ! and searching tools, as well as the means for registering the 
  ! domain decompositions for a single component or with a        
  ! framework                                                     
  !
  !
  !If the CON\_world is modified, use the following lines for     
  !renaming. The functions like i\_proc()         should give the 
  !rank in the global communicator etc. NOTE: CON\_stop is the    
  !interface procedure.                                              

  !USES:
  use ModUtilities,ONLY:check_allocate
  use CON_world
  use ModNumConst                                               
  use ModMpi
  use ModKind, ONLY: nByteReal

  !REVISION HISTORY:
  ! 6/18/03-7/11/03 Sokolov I.V. <igorsok@umich.edu> phone(734)647-4705
  !EOP
  !===============================================================

  implicit none                                                 
  SAVE
  real, parameter :: cThird = 1.0/3.0

  integer,parameter::Parent_=-1,&                               
       MyNumberAsAChild_ =0,&                                   
       FirstChild_  =1,&                                        
       BLK_         =2,&                                        
       PE_          =3,&
       GlobalBlock_ =4,&
       None_        =-777                                       
  !BOP
  !DESCRIPTION:
  !\begin{verbatim}                                
  !=====================DERIVED TYPE==============================
  type DomainType
     ! The type is to describe the domain decomposition for a        
     ! component. The component should be properly registered with   
     ! registry procedures and should have a unique ID               

     integer :: CompID_

     !This type describes the general decomposition for rectangular  
     !box domain.                                                    
     !Below ":=" means "according to definition".                    
     !Describe the property of the !domain first.                    
     !=============================DOMAIN============================
     !genaralized coordinates := the coordinates with respect to     
     !    which the domain decomposition chunks are uniform.         
     !nDim := the dimensionality of the generalized coordinate space 

     integer ::nDim                

     !---------------------------------------------------------------
     !domain := (nDim)-dimensional rectangular box, such as the      
     ! data used by the component CompID_ can be associated with the 
     ! points inside of this domain                                  
     !                                                               
     ! XyzMin_D:=Coordinates of the left corner of the domain        
     ! XyzMax_D:=Coordinates of the right corner of the computational
     ! left corner:=the common point of all left boundary faces,     
     ! each of the nDim left boundary faces being defined with       
     ! respect to the correspondent direction                        

     real,dimension(:),pointer::XyzMin_D,XyzMax_D

     !================ROOT DECOMPOSITION=============================
     !Root decomposition:=  decomposition of the domain for          
     !iRootMapDim_D(1)*iRootMamDim_D(2)*.....iRootMapDim_D(nDim)     
     !blocks, which are spatially uniform in geralized coordinates   
     !block:=rectangular box.                                        
     !                                                               
     !                                                               
     !The principle "block is not shared" is assumed, that is if the 
     !physical data at any point geometrically belonging to the block
     !are allocated at the given PE, then all the points in the      
     !Component, which geometrically belong to this block, should be 
     !also allocated at the same PE.                                 
     !                                                               
     !(For the uniformly spaced grids the root decomposition is the  
     ! map of blocks, for tree grid - the map of the roots)          

     integer,dimension(:),pointer::iRootMapDim_D


     !================CELL DECOMPOSITION=============================
     !Cell decomposition:=decomposition of each of the blocks for    
     !nCells_D(1)*nCells_D(2)*.....nCells_D(nDim) cells,             
     !which are spatially uniform in the geralized coordinates       
     !                                                               
     !So, it is assumed that the domain is fully decomposed for   
     !"blocks" and just in an analogous manner we assume that the    
     !region covered by blocks can be decomposed for "cells".               
     !Searching programs given here allow to find the number of block 
     !point and the vector of the cell numbers, for the cell to which    
     !with coordinates x,(y,z) belongs. The availbability of these    
     !programs still DOES NOT require to use these cells for the     
     !control volume method. The actual grid points can be chosen to 
     !be  at the vertexes, faces, edges and so on. See the           
     !explanations for grid descriptors in CON_router                
     !Nevertheless usually the indexes of cell the point belongs to                 
     !allow to find readily the number of the nearest node, nearest 
     !edge and so on.               

     integer,dimension(:),pointer::nCells_D     

     !============TREE DECOMPOSITION=================================
     !RECURSIVE DEFINITION:                                           
     !tree decomposition:= root decomposition .or.&                  
     !     refinement[tree decomposition]                            
     !refinement:=decompose any block for 2*nDimTree (nDimTree<=nDim)
     !blocks by splitting the original block for two equal parts     
     !along each of the first nDimTree dimensions                    
     !                                                               
     !The mathematical space of tree decompositions, for a given     
     !iRootMapDim_D can be one-to-one mapped to the space of         
     !structures, consisting of product(iRootMapDim_D) tree graphs.  
     !Each node of this tree corresponds to either a root map        
     !element, or the block, which was refined, or a block.          
     !                                                               
     !If the tree decomposition is allowed for a given domain, set   
     !IsTreeGrid=.true.                                              

     logical::IsTreeDecomposition

     !Octree or Quadric tree. Is only used for the decomposition with 
     !IsTreeDecomposition=.true.                                     

     integer ::nDimTree 

     ! nChildren=2**nDimTree for the tree grid                       

     integer :: nChildren

     !====================DESCRIPTOR FOR TREE DECOMPOSITIONS=========
     !For tree decomposition this is a full tree structure saved as  
     !described in the figure (PE is a CPU rank in a i_comm(Global_) 

     integer,dimension(:,:),pointer::iDecomposition_II

     !---------------------------------------------------------------
     !                                                               
     !------Root  node of tree ----------             ...            
     !                                                /              
     !   RootNumber,MyNumberAsAChild=0--ChildAdresses()              
     !                                                \ (1:nChildren)
     !                                                 ...           
     !                                                               
     !------Non-end node of tree---------                            
     !                   ...             ...                         
     !                  /                 /                          
     !   ParentAddress--MyNumberAsAChild--ChildAdresses()            
     !                  \                 \(1:nChildren)             
     !                   ...              ...                        
     !                                                               
     !------End node of tree-------------                            
     !                 ...                                           
     !                  /            information for used blocks     
     !   ParentAddress--MyNumberAsAChild,    (PE,BLK),               
     !                  \            "address of the first           
     !                  ...           child"=None_                   
     !                                                               
     !---------------------------------------------------------------
     !For non-tree grid: each block is both a root node and an end   
     !node.                                                          
     !                                                               
     !For each lGlobalTreeNumber (second index) the vector           
     !iDecomposition_II(:,lGlobalTreeNumber)                         
     !is                                                             
     !(lGlobalTreeNumber(Root Number),&                              
     !0 (MyNumberAsAChild),&                                         
     !None_(FirstChild_),&                                           
     !PE_(lGlobalTreeNumber),&                                       
     !BLK_(lGlobalTreeNumber).                                       
     !                                                               
     !In this case iDecomposition_II is a root decomposition,        
     !which is accompanied by some markers, allowing to apply the    
     !same searching programs for tree- and non-tree- grids          
     !                                                               
     !---------------------------------------------------------------
     !nTreeNodes - the number of blocks,                             
     !for non-tree grid, or the number of all nodes                  
     !in the tree.                                                   

     integer::nTreeNodes,nAllocatedNodes  

     !---------------------------------------------------------------
     !The following is not allocated if the grid is a tree grid.     
     !The GlobalTree of the tree roots in the                        
     !iDecomposition_II array (the values for the second index       
     integer,dimension(:),pointer::iRoot_I       

     !==============REFINEMENT DESCRIPTOR============================
     !Parent Block:= the lGlobalNode for the block which disappears  
     ! in the coarse of the refinement procedure as described above  
     !Children:= the values of lGlobalNode for the nChildren blocks  
     !appearing as the results of the refinement procedures          
     !                                                               
     !refinement[iDecomposition_II]:=&                               
     !begin algorithm                                                
     !choose lParent=lGlobalNode to be refined                       
     !if(iDecomposition_II(FirstChild_,lParent)/=None)&              
     !   stop('The Node can not be re-refined')!                     
     !do lGlobalNodes=1,nTreeNodes                                   
     !if (iDecomposition_II(FirstChild_,lGlobalNode)==None_) CYCLE   
     !if(iDecomposition_II(Parent_,lGlobalNode)>lParent)&            
     !iDecomposition_II(Parent_,lGlobalNode)=&                       
     !iDecomposition_II(Parent_,lGlobalNode)+nChildren               
     !where(iDecomposition_II(1:nChildren,lGlobalNode)>lParent)&     
     !iDecomposition_II(1:nChildren,lGlobalNode)=&                   
     !iDecomposition_II(1:nChildren,lGlobalNode)+nChildren           
     !end do                                                         
     !iDecomposition_II(1:nChildren,lParent)=&                       
     !     lParent+1:lParent+nChildren                               
     ! (or reordering(lParent+1:lParent+nChildren) in accordance with
     !   the Hilbert_Peano curve)                                    
     !iDecomposition_II(Parent_,lParent+1:lParent+nChildren)         
     !iDecomposition_II(Parent_,lParent+1:lParent+nChildren)         
     !end algorithm                                                  
     !                                                               
     !After this the values for                                      
     !iDecomposition_II(PE_:BLK_,lParent+1:lParent+nChildren)        
     !should be assigned to be exactly the same as in the component  
     !to set the relationship between the ChildNumber in              
     !iDecomposition and the concrete block in the component we use  
     !geometric relationships.                                       
     !                                                               
     !Introduce the array nDimTree*nChildren, which defines the      
     !spacial shift vector of the Child's zero corner with respect to
     !the parent zero corner, measured in the Child block size units.
     !This shifht is unambigous function of the child number         
     !                                                               
     !In index I  passing from 1 to nChildren, all the possible      
     !combinations of 0 and 1 of dimension nDimTree should be        
     !unambigously related to the values of I In the grid captured by 
     !the control module, this array should be organized exaclty as  
     !it done in the "component".                                    

     integer,dimension(:,:),pointer::iShift_DI

     !===============GEOMETRY CHARACTERISTICS========================
     !In principle, the array introduced above contains all the      
     !geometric characteristics, however it is not convenient to     
     !calculate it each time. Tree more arrays are stored for each   
     !domain decomposition                                           
     !                                                               
     !XyzBlock_DI are the generalized coordinates of the left corner 
     !of the block,                                                   

     real,dimension(:,:),pointer::XyzBlock_DI 

     ! DXyzBlock_D is the BLOCK size                                 

     real,dimension(:,:),pointer::DXyzBlock_DI 

     ! and DXyzCell_D is the cell size.                              

     real,dimension(:,:),pointer::DXyzCell_DI 

     ! First index inumerates the spatial component of the           
     ! generalized coordinates, second is lGlobalNode                

     !==========SPECIAL BOUNDARIES===================================
     !Sometimes the coordinate values which are arithmetically beyond
     !the limit values XyzMin_D, XyzMax_D, geometrically appear to be
     !inside the domain. The simplest example is given by periodic   
     !boundary conditions. For the domain with periodic boundary     
     !conditions the following array is introduced                   

     logical,dimension(:),pointer::IsPeriodic_D  

     !For more complicated cases (spherical and analogous geometries 
     !having a pole singularity) a special procedure                 
     !glue_margin is invoked when required. To do this     
     !for a particular grid, it should have DoGlueMargins=.true.     

     logical :: DoGlueMargins
     integer :: iDirMinusGlue, iDirPlusGlue, iDirCycle
     !==========SOME INTEGERS========================================
     !To search in the tree decompositions  it is optimal to start   
     !from the previously found node (from the previous search). To  
     !do this we have this previuosly found value saved in lSearch   

     integer::lSearch                        

     !For the grids which can be refined, the realization number for 
     !the domain decomposition should be stored

     integer:: iRealization

     !===================LOCAL AND GLOBAL DECOMPOSITIONS=============
     !In the local decomposition the PE ranks are defined to be in a 
     !local communicator, for a particular component                 

     logical::IsLocal

     !The derived type described below consists of decompositions,   
     !for which IsLocal=.false., but if the decomposition allows     
     !refinement, there must be a local decompositions in the        
     !correspondent model which accounts for any refinements as soon 
     !as they are done. The changes in iDecomoposition_II array then 
     !can come to the array DD_I only through the procedure          
     !synchronize
     !
     !The inverse mapping (iPE,iBLK)->global node number is mantained
     !using the following components:
     
     integer::MinBlock,MaxBlock
     integer,dimension(:,:),pointer::iGlobal_BP

     !The inverse mapping GlobalBlock number->global node number 
     !is mantained using the following components:
     
     integer::nBlockAll
     integer,dimension(:),pointer::iGlobal_A

     !===============================================================
     !\end{verbatim}

  end type DomainType
  !EOP
  !================DERIVED TYPE===================================
  type DomainPointerType
     type(DomainType),pointer::Ptr
  end type DomainPointerType

  !Needed for searching and interpolating algorithms
  real, parameter:: &
       cTol  = 0.00000010, &
       cTol2 = cTol**(nByteReal/4)
  real, parameter:: &
       cAlmostOne   = 1.0 - cTol2,&
       cAlmostTwo   = 2*cAlmostOne,&
       cAlmostHalf  = 0.5*cAlmostOne

contains
  !===============================================================!
  !BOP
  !INTERFACE:
  subroutine init_decomposition_dd(&
       Domain,&
       CompID_,&            !As in DomainType
       nDim,&               !As in DomainType
       IsTreeDecomposition,&!As in DomainType
       nDimTree,IsLocal)

    !INPUT ARGUMENTS:
    type(DomainType),intent(inout)::&
         Domain
    integer,intent(in)::CompID_,nDim
    logical,intent(in),optional::IsTreeDecomposition
    integer,intent(in),optional::nDimTree 
    logical,intent(in),optional::IsLocal
    !EOP
    integer::iError,iDim,iChildFirst,iChildLast          

    if(use_comp(CompID_))then
       Domain%CompID_=CompID_
    else
       call CON_stop(&
            'Unauthorized use of the component')
    end if

    if(present(IsTreeDecomposition))then
       Domain%IsTreeDecomposition=&
            IsTreeDecomposition
    else
       Domain%IsTreeDecomposition=.false.
    end if

    Domain%nDim=nDim
    if(Domain%IsTreeDecomposition)then
       if(.not.present(nDimTree))then
          Domain%nDimTree=nDim
       else
          Domain%nDimTree=nDimTree
       end if
       Domain%nChildren=&
            2**Domain%nDimTree
    else
       Domain%nChildren=1       
    end if

    nullify(Domain%iRootMapDim_D)
    allocate(Domain%iRootMapDim_D(&
         nDim),stat=iError)
    call check_allocate(iError,"iRootMapDim_D")
    Domain%iRootMapDim_D=1

    nullify(Domain%XyzMin_D)
    allocate(Domain%XyzMin_D(nDim),stat=iError)
    call check_allocate(iError,"XyzMin_D")
    Domain%XyzMin_D=cZero

    nullify(Domain%XyzMax_D)
    allocate(Domain%XyzMax_D(nDim),stat=iError)
    call check_allocate(iError,"XyzMax_D")
    Domain%XyzMax_D=cOne

    nullify(Domain%nCells_D)
    allocate(Domain%nCells_D(nDim),stat=iError)
    call check_allocate(iError,"nCells_D")
    Domain%nCells_D=1

    nullify(Domain%IsPeriodic_D)
    allocate(&
         Domain%IsPeriodic_D(nDim),stat=iError)
    call check_allocate(iError,"IsPeriodic_D")
    Domain%IsPeriodic_D=.false.
    Domain%DoGlueMargins=.false.
    Domain%iDirMinusGlue = 0 
    Domain%iDirPlusGlue  = 0 
    Domain%iDirCycle     = 0

    if(Domain%IsTreeDecomposition)then
       nullify(Domain%iRoot_I)
       call allocate_iroot(Domain)

       nullify(Domain%iShift_DI)
       allocate(Domain%iShift_DI&
            (Domain%nDimTree,&
            Domain%nChildren),stat=iError)
       call check_allocate(iError,"iShift_DI")
       Domain%iShift_DI=0
       ! A "binary" order for iShift_DI is set as a default:
       !(0,0,0,&
       ! 1,0,0,&
       ! 0,1,0,&
       ! and so on
       !
       iChildLast=1
       do iDim=1,Domain%nDimTree
          iChildFirst=iChildLast+1
          iChildLast=min(&
               Domain%nChildren,2*iChildLast)
          if(iChildFirst<iChildLast)exit
          Domain%iShift_DI(&
               :,iChildFirst:iChildLast)=&
               Domain%iShift_DI(&
               :,1:1+iChildLast-iChildFirst)
          Domain%iShift_DI(&
               iDim,iChildFirst:iChildLast)=1
       end do
    end if

    if(present(IsLocal))then
       Domain%IsLocal=IsLocal
    else
       Domain%IsLocal=.false.
    end if

    Domain%nTreeNodes=1
    Domain%nAllocatedNodes=-1

    nullify(Domain%iDecomposition_II)
    nullify(Domain%XyzBlock_DI) 
    nullify(Domain%DXyzBlock_DI)
    nullify(Domain%DXyzCell_DI)
    call check_octree_grid_allocation(Domain)
    Domain%lSearch=1
    Domain%iRealization=0
    nullify(Domain%iGlobal_BP)
    Domain%MinBlock=1
    Domain%MaxBlock=1
    if(Domain%IsLocal)then
       allocate(Domain%iGlobal_BP(1:1,&
            0:-1+n_proc(Domain%CompID_)),&
            stat=iError)
    else
       allocate(Domain%iGlobal_BP(1:1,&
            0:&
            i_proc_last(CompID_)),&
            stat=iError)
    end if
    call check_allocate(iError,'iGlobal_BP,first allocation')
    Domain%nBlockAll=1
    nullify(Domain%iGlobal_A)
    allocate(Domain%iGlobal_A(&
         1:Domain%nBlockAll),&
         stat=iError)
    call check_allocate(iError,'iGlobal_A,first allocation')
  end subroutine init_decomposition_dd
  !===============================================================!
  !============================NO INTERFACE=======================!

  !Checks the array allocation for a given grid desciptor and     
  !extends its dimension if required                              

  subroutine check_octree_grid_allocation(Domain)
    type(DomainType),intent(inout)::&
         Domain
    integer::iError,nUbound

    nUbound= GlobalBlock_
    if(Domain%IsTreeDecomposition)&
         nUbound=max(nUbound,Domain%nChildren)
    if(Domain%nAllocatedNodes>=&
         Domain%nTreeNodes)return
    if(associated(Domain%iDecomposition_II))then
       deallocate(Domain%iDecomposition_II,stat=iError)
       deallocate(Domain%XyzBlock_DI,stat=iError)
       deallocate(Domain%DXyzBlock_DI,stat=iError)
       deallocate(Domain%DXyzCell_DI,stat=iError)
    end if

    nullify(Domain%iDecomposition_II)
    allocate(&
         Domain%iDecomposition_II&
         (Parent_:nUBound,&
         Domain%nTreeNodes)&
         ,stat=iError)
    call check_allocate(iError,'iDecomposition_II')
    Domain%iDecomposition_II=None_
    Domain%iDecomposition_II(&
         MyNumberAsAChild_,:)=0

    nullify(Domain%XyzBlock_DI)
    allocate(&
         Domain%XyzBlock_DI&
         (Domain%nDim,&
         Domain%nTreeNodes)&
         ,stat=iError)
    call  check_allocate(iError,'XyzBlock_DI')
    Domain% XyzBlock_DI=cZero    

    nullify(Domain%DXyzBlock_DI)
    allocate(&
         Domain%DXyzBlock_DI&
         (Domain%nDim,&
         Domain%nTreeNodes)&
         ,stat=iError)
    call  check_allocate(iError,'DXyzBlock_DI')
    Domain%DXyzBlock_DI=cOne

    nullify(Domain%DXyzCell_DI)
    allocate(&
         Domain%DXyzCell_DI&
         (Domain%nDim,&
         Domain%nTreeNodes)&
         ,stat=iError)
    call  check_allocate(iError,'DXyzCell_DI')
    Domain%DXyzCell_DI=cOne

    Domain%nAllocatedNodes=&
         Domain%nTreeNodes
  end subroutine check_octree_grid_allocation
  !==========================WITH INTERFACE=======================!
  !BOP
  !IROUTINE: get_root_decomposition - get the domain decomposition
  !DESCRIPTION:
  !\begin{verbatim}
  !===============================================================!
  !To get a decomposition domain, even the tree one, the root     !
  !decomposition should be first constructed                      !
  !====================ATTENTION==================================!
  !PE here are the ranks in the LOCAL communicator for the        !
  !component  
  !\end{verbatim}
  !EOP

  !BOP
  !INTERFACE:
  subroutine get_root_decomposition_dd(&
       Domain,&!Decomposition to be constructed
       iRootMapDim_D,&!As in DomainType
       XyzMin_D,&     !As in DomainType
       XyzMax_D,&     !As in DomainType
       nCells_D,&     !As in DomainType
       PE_I,&         !PE layout
       iBlock_I,&     !Local Block Number layout
       IsPeriodic_D,& !As in DomainType
       iShift_DI,   & !As in DomainType
       DoGlueMargins,& !As in DomainType
       iDirMinusGlue,&!As in DomainType
       iDirPlusGlue,& !As in DomainType
       iDirCycle)     !As in DomainType
    !INPUT ARGUMENTS:
    type(DomainType),intent(inout)::&
         Domain
    integer,dimension(Domain%nDim),&
         intent(in)::iRootMapDim_D
    real,dimension(Domain%nDim),&
         intent(in)::XyzMin_D   
    real,dimension(Domain%nDim),&
         intent(in)::XyzMax_D
    integer,dimension(Domain%nDim),&
         intent(in)::nCells_D
    integer,dimension(:),&
         intent(in),optional:: PE_I,iBlock_I
    logical,dimension(Domain%nDim),&
         intent(in),optional::IsPeriodic_D
    integer,optional,&
         dimension(Domain%nDim,&
         Domain%nChildren),&
         intent(in)::iShift_DI
    logical, intent(in), optional :: DoGlueMargins
    integer, intent(in), optional :: iDirMinusGlue
    integer, intent(in), optional :: iDirPlusGlue
    integer, intent(in), optional :: iDirCycle
    !-------
    integer::lBlock,MaxBlock
    !EOP
    !---------------------------------------------------------------!
    !Check the dimension of PE_I and iBlock_I                       !
    if(present(PE_I))then
       if(ubound(PE_I,1)/=product(iRootMapDim_D))then
          call CON_stop('The dimension of PE_I is wrong')
       end if
    end if

    if(present(iBlock_I))then
       if(ubound(iBlock_I,1)/=product(iRootMapDim_D))&
            call CON_stop('The dimension of iBlock_I is wrong')
    end if

    !---------------------------------------------------------------!
    !Assign the grid parameters                                     !

    Domain%iRootMapDim_D=iRootMapDim_D

    Domain%XyzMin_D=XyzMin_D
    Domain%XyzMax_D=XyzMax_D
    Domain%nCells_D=nCells_D
    if(present(DoGlueMargins)) &
         Domain%DoGlueMargins = DoGlueMargins
    if(present(iDirMinusGlue))&
         Domain%iDirMinusGlue = iDirMinusGlue
    if(present(iDirPlusGlue)) &
         Domain%iDirPlusGlue  = iDirPlusGlue
    if(present(iDirCycle))    &
         Domain%iDirCycle     = iDirCycle

    if(present(IsPeriodic_D))&
         Domain%IsPeriodic_D=IsPeriodic_D

    Domain%nTreeNodes=product(iRootMapDim_D)
    call check_octree_grid_allocation(Domain)


    Domain%iDecomposition_II&
         (MyNumberAsAChild_,1:Domain%nTreeNodes)=0    
    Domain%iDecomposition_II&
         (FirstChild_,1:Domain%nTreeNodes)=None_
    do lBlock=1,Domain%nTreeNodes
       Domain%iDecomposition_II(Parent_,lBlock)=lBlock
    end do

    if(Domain%IsTreeDecomposition)then
       call check_iroot_allocation(Domain)
       if(present(iShift_DI))&
            Domain%iShift_DI=iShift_DI
    end if

    !BOP
    !DESCRIPTION:
    !If neither PE\_I nor iBlock\_I is present, the root 
    !decomposition blocks are balanced for an optimal load
    !EOP
    if((.not.present(PE_I)).and.(.not.present(iBlock_I)))then
       MaxBlock=(Domain%nTreeNodes-1)/&
            n_proc(Domain%CompID_)+1
       do lBlock=1,Domain%nTreeNodes
          call set_pe_and_local_blk_dd(Domain,&
               lBlock,&
               iPE=(lBlock-1)/MaxBlock,&
               iBlock=mod(lBlock,MaxBlock)+1)
       end do
       call set_iglobal_and_bp_dd(Domain)
       return
    end if
    !BOP
    !DESCRIPTION:
    !If the PE\_I is not given, it is assumed that all the blocks    
    !are at the root PE
    !EOP                                             
    if(present(PE_I))then
       Domain%iDecomposition_II&
            (PE_,1:Domain%nTreeNodes)=PE_I
    else
       Domain%iDecomposition_II&
            (PE_,1:Domain%nTreeNodes)=0
    end if
    !BOP
    !DESCRIPTION:
    !\begin{verbatim}
    !If the iBlock_I is not given, they are assumed to be enumerated
    !like in the following loop:                                    
    !      lBlock=0                                                 
    !      do kRoot=1,iRootMapDim_D(3)                              
    !          do jRoot=1,iRootMapDim_D(2)                          
    !             do iRoot=1,iRootMapDim_D(1)                       
    !               lBlock=lBlock+1                                 
    !               BLK(iRoot,jRoot,kRoot)=lBlock                   
    !             end do                                            
    !          end do                                               
    !      end do    
    !\end{verbatim}                                               
    !EOP 
    if(present(iBlock_I))then
       Domain%iDecomposition_II&
            (BLK_,1:Domain%nTreeNodes)=iBlock_I
    else
       do lBlock=1, Domain%nTreeNodes
          Domain%iDecomposition_II&
               (BLK_,lBlock)=lBlock
       end do
    end if
    call set_iglobal_and_bp_dd(Domain)
  end subroutine get_root_decomposition_dd
  !===============================================================!
  subroutine set_pe_and_local_blk_dd(&
       Domain,lGlobalTreeNode,iPE,iBlock)
    type(DomainType),intent(inout)::&
         Domain
    integer,intent(in)::lGlobalTreeNode,iPE,iBlock
    if(Domain%iDecomposition_II&
         (FirstChild_,lGlobalTreeNode)/=None_)call CON_stop(&
         'You can not assign pe and blk for tree node')

    Domain%iDecomposition_II&
         (BLK_,lGlobalTreeNode)=iBlock
    Domain%iDecomposition_II&
         (PE_,lGlobalTreeNode)=iPE
  end subroutine set_pe_and_local_blk_dd
  !===============================================================!
  subroutine set_iglobal_and_bp_dd(Domain)
    type(DomainType),intent(inout)::&
         Domain
    integer::iUpper_I(2),iLower_I(2),iError,iPE,iBlock
    integer::iGlobalNode,iGlobalBlock
    iLower_I=lbound(Domain%iGlobal_BP)
    iUpper_I=ubound(Domain%iGlobal_BP)
    Domain%MinBlock=minval(&
         Domain%iDecomposition_II(&
         BLK_,1:Domain%nTreeNodes),MASK=&
         Domain%iDecomposition_II(&
         FirstChild_,1:Domain%nTreeNodes)==None_&
         .and.Domain%iDecomposition_II(&
         PE_,1:Domain%nTreeNodes)/=None_)
    Domain%MaxBlock=maxval(&
         Domain%iDecomposition_II(&
         BLK_,1:Domain%nTreeNodes),MASK=&
         Domain%iDecomposition_II(&
         FirstChild_,1:Domain%nTreeNodes)==None_&
         .and.Domain%iDecomposition_II(&
         PE_,1:Domain%nTreeNodes)/=None_)
    Domain%nBlockAll=count(&
         Domain%iDecomposition_II(&
         FirstChild_,1:Domain%nTreeNodes)==None_&
         .and.Domain%iDecomposition_II(&
         PE_,1:Domain%nTreeNodes)/=None_)
    if(iUpper_I(1)<Domain%MaxBlock.or.&
         iLower_I(1)>Domain%MinBlock)then
       deallocate(Domain%iGlobal_BP)
       allocate(Domain%iGlobal_BP(&
            Domain%MinBlock:&
            Domain%MaxBlock,&
            iLower_I(2):iUpper_I(2)),&
            stat=iError)
       call check_allocate(iError,'iGlobal_BP - reallocate')
    end if
    if(ubound(Domain%iGlobal_A,1)<&
         Domain%nBlockAll)then
       deallocate(Domain%iGlobal_A)
       allocate(Domain%iGlobal_A(&
            1:Domain%nBlockAll),&
            stat=iError)
       call check_allocate(iError,'iGlobal_BP - reallocate')
    end if
    Domain%iGlobal_BP=None_
    Domain%iGlobal_A=None_
    iGlobalBlock=0
    do iGlobalNode=1,Domain%nTreeNodes
       if(.not.is_used_block_dd(Domain,iGlobalNode))&
            CYCLE
       call pe_and_blk_dd(Domain,iGlobalNode,&
            iPE,iBlock)
       Domain%iGlobal_BP(iBlock,iPE)=iGlobalNode
       iGlobalBlock=iGlobalBlock+1
       Domain%iDecomposition_II(GlobalBlock_,&
            iGlobalNode)=iGlobalBlock
       Domain%iGlobal_A(iGlobalBlock)=iGlobalNode
    end do

  end subroutine set_iglobal_and_bp_dd
  !=====================NO INTERFACE==============================!

  !===============================================================!
  !Allocates the part of the grid descriptor which is only used 
  !with octree grids. Checks the allocation for the arrayes needed
  !for octree grids, allocate if required.
  ! Checks the dimension and extends the arrays if required.
  !---------------------------------------------------------------!
  subroutine allocate_iroot(Domain)
    type(DomainType),intent(inout)::&
         Domain
    integer::iError
    if(associated(Domain%iRoot_I))then
       deallocate(Domain%iRoot_I)
    end if
    allocate(&
         Domain%iRoot_I(product(&
         Domain%iRootMapDim_D)),&
         stat=iError)
    call check_allocate(iError,'iRoot_I')
    Domain%iRoot_I=None_
  end subroutine allocate_iroot
  !---------------------------------------------------------------!
  subroutine check_iroot_allocation(Domain)
    type(DomainType),intent(inout)::&
         Domain
    if(ubound(Domain%iRoot_I,1)<product(&
         Domain%iRootMapDim_D))&
         call allocate_iroot(Domain)
  end subroutine check_iroot_allocation
 
  !===========================WITH INTERFACE======================!
  !===============================================================!
  !BOP
  !IROUTINE: bcast_decomposition - send decomposition to all PEs
  !DESCRIPTION:
  !Broadcasts a given grid descriptor from the root PE            
  !via the global communicator iComm                              
  !EOP

  !BOP
  !INTERFACE:
  subroutine bcast_decomposition_dd(Domain)

    !INPUT ARGUMENTS:
    type (DomainType),intent(inout)::&
         Domain
    !EOP
    integer::iComm 
    integer::iProc0
    integer::iError

    if(Domain%IsLocal)then
       iComm=i_comm(Domain%CompID_)
       iProc0=0
    else
       iComm=i_comm()
       iProc0=i_proc0(Domain%CompID_)
    end if
    call MPI_Bcast(Domain%IsPeriodic_D(1),&
         Domain%nDim,MPI_LOGICAL,&
         iProc0,iComm,iError)

    call MPI_Bcast(Domain%XyzMin_D(1),&
         Domain%nDim,MPI_REAL,&
         iProc0,iComm,iError)

    call MPI_Bcast(Domain%XyzMax_D(1),&
         Domain%nDim,MPI_REAL,&
         iProc0,iComm,iError)

    call MPI_Bcast(Domain%iRootMapDim_D(1),&
         Domain%nDim,MPI_INTEGER,&
         iProc0,iComm,iError)

    call MPI_Bcast(Domain%nCells_D(1),&
         Domain%nDim,MPI_INTEGER,&
         iProc0,iComm,iError)

    if(Domain%IsTreeDecomposition)then
       call check_iroot_allocation(Domain)
       call MPI_Bcast(Domain%iShift_DI(1,1),&
            Domain%nDim*&
            Domain%nChildren,&
            MPI_INTEGER,&
            iProc0, iComm,iError)   
    end if
    call bcast_indexes_dd(&
         Domain)    

    call MPI_Bcast(Domain%DoGlueMargins,&
         1,MPI_LOGICAL,iProc0,iComm,iError)

    call MPI_Bcast(Domain%iDirMinusGlue,&
         1,MPI_INTEGER,iProc0,iComm,iError)

    call MPI_Bcast(Domain%iDirPlusGlue,&
         1,MPI_INTEGER,iProc0,iComm,iError)

    call MPI_Bcast(Domain%iDirCycle,&
         1,MPI_INTEGER,iProc0,iComm,iError)

  end subroutine bcast_decomposition_dd
  !---------------------------------------------------------------!
  !
  !IROUTINE: bcast_indexes - send the indexes of the decomposition
  !DESCRIPTION:
  !Broadcasts only Decomposition\_II. This is a part of the
  !synchronize\_refinement procedure, but it can be used separately 
  !too. If any of the optional parameters is not present, the 
  !Decomposition\_II array is sent from the root processor of the 
  !components to all PEs in the global communicator, otherwise
  !it itis sent FROM the PE having the rank iProcUnion in the 
  !communicator iCommUnion TO all PEs of this communicator.  
  !Recalculate local PE ranks to their values in the global       
  !communicator while broadcasting.

  !INTERFACE:
  subroutine bcast_indexes_dd(&
       Domain,iProcUnion,iCommUnion)
    !INPUT ARGUMENTS:
    type (DomainType),intent(inout)::&
         Domain
    integer,optional,intent(in)::iProcUnion,iCommUnion

    integer::iComm 
    integer::iProc0
    integer::iError
    if(present(iProcUnion).and.present(iCommUnion))then
       iComm=iCommUnion
       iProc0=iProcUnion
    elseif(Domain%IsLocal)then
       iComm=i_comm(Domain%CompID_)
       iProc0=0
    else
       iComm=i_comm()
       iProc0=i_proc0(Domain%CompID_)
    end if

    call MPI_Bcast(Domain%nTreeNodes,&
         1,MPI_INTEGER,&
         iProc0, iComm,iError)   
    call check_octree_grid_allocation(Domain)

    if(.not.Domain%IsLocal.and.&
         is_proc0(Domain%CompID_))then
       ! Recalculate local PE ranks to their values in the global      !
       ! communicator (at the root pe only)                            ! 
       where(Domain%iDecomposition_II(&
            FirstChild_,1:Domain%nTreeNodes)&
            ==None_&
            .and.Domain%iDecomposition_II(&
            PE_,1:Domain%nTreeNodes)/=None_)&
            Domain%iDecomposition_II(&
            PE_,1:Domain%nTreeNodes)=&
            i_proc0()+i_proc0(Domain%CompID_)+&
            Domain%iDecomposition_II(&
            PE_,1:Domain%nTreeNodes)*&
            i_proc_stride(Domain%CompID_)
    end if

    call MPI_Bcast(Domain%iDecomposition_II(-1,1),&
         (2+ubound(Domain%iDecomposition_II,1))*&
         Domain%nTreeNodes,&
         MPI_INTEGER,iProc0,iComm,iError)

    call MPI_Bcast(Domain%iRealization,&
         1,MPI_INTEGER,&
         iProc0, iComm,iError)

    call complete_grid(Domain)
  end subroutine bcast_indexes_dd
  !===========================NO INTERFACE========================!
  !complete_grid recovers the geometric variables in situ         !

  subroutine complete_grid(Domain)
    type (DomainType),intent(inout)::&
         Domain
    real,dimension(Domain%nDim)::DXyzRoot_D
    integer::lGlobalTreeNumber,lRoot,i,iDim,nDim
    integer::iRootCounter,lParent,iChildNumber

    DXyzRoot_D=(Domain%XyzMax_D-&
         Domain%XyzMin_D)/&
         Domain%iRootMapDim_D
    nDim=Domain%nDim

    iRootCounter=0
    do lGlobalTreeNumber=1,Domain%nTreeNodes
       if(Domain%iDecomposition_II(&
            MyNumberAsAChild_,lGlobalTreeNumber)==0)then
          iRootCounter=iRootCounter+1
          Domain%DXyzBlock_DI(&
               :,lGlobalTreeNumber)=DXyzRoot_D
          Domain%DXyzCell_DI(&
               :,lGlobalTreeNumber)=DXyzRoot_D/&
               Domain%nCells_D
          Domain%iDecomposition_II(&
               Parent_,lGlobalTreeNumber)=iRootCounter
          lRoot=iRootCounter-1
          do iDim=1,nDim
             i=mod(lRoot,&
                  Domain%iRootMapDim_D(iDim))
             Domain%XyzBlock_DI(&
                  iDim,lGlobalTreeNumber)=&
                  Domain%XyzMin_D(iDim)+&
                  i*DXyzRoot_D(iDim)
             lRoot=(lRoot-i)/&
                  Domain%iRootMapDim_D(iDim)
          end do
          if(Domain%IsTreeDecomposition)&
               Domain%iRoot_I(&
               iRootCounter)=lGlobalTreeNumber
       else
          lParent=Domain%iDecomposition_II(&
               Parent_,lGlobalTreeNumber)
          Domain%DXyzBlock_DI(&
               :,lGlobalTreeNumber)=&
               Domain%DXyzBlock_DI(:,lParent)
          Domain%DXyzBlock_DI(&
               1:Domain%nDimTree,lGlobalTreeNumber&
               )=cHalf*Domain%DXyzBlock_DI(&
               1:Domain%nDimTree,lGlobalTreeNumber)
          Domain%DXyzCell_DI(&
               :,lGlobalTreeNumber)=&
               Domain%DXyzBlock_DI(&
               :,lGlobalTreeNumber)/&
               Domain%nCells_D
          Domain%XyzBlock_DI(:,lGlobalTreeNumber)&
               =Domain%XyzBlock_DI(:,lParent)
          iChildNumber=&
               Domain%iDecomposition_II(&
               MyNumberAsAChild_,lGlobalTreeNumber)
          Domain%XyzBlock_DI(&
               1:Domain%nDimTree,lGlobalTreeNumber)&
               =Domain%XyzBlock_DI(&
               1:Domain%nDimTree,lGlobalTreeNumber)&
               +Domain%DXyzBlock_DI(&
               1:Domain%nDimTree,lGlobalTreeNumber)&
               *Domain%iShift_DI(:,iChildNumber)
       end if
    end do
    call set_iglobal_and_bp_dd(Domain)
  end subroutine complete_grid

  !===============================================================!
  !BOP
  !IROUTINE: synchronize_refinement - update decomposition after AMR
  !DESCRIPTION:
  !\begin{verbatim}
  !           SYNCHRONIZE LOCAL AND GLOBAL GRID                  
  !           NOTE: IF GridID\_ is used for global grid, then      
  !           synchronize\_refinement is the only way to properly  
  !           account for the refinement
  !
  !If any of the optional parameters is not present, the global 
  !decomposition at all the PEs of the global communicator is 
  !synchronized with the local one at root processor of the 
  !component. Otherwise the global 
  !decomposition at all the PEs of the communicator iProcUnion is 
  !synchronized with the local one at the PE having the rank 
  !iProcUnion in the communicator iCommUnion.
  !Recalculate local PE ranks (of the local grid) to their values 
  !in the global communicator (i\_comm()).
  !\end{verbatim}                          
  !EOP

  !BOP
  !INTERFACE:
  subroutine synchronize_refinement_dd(&
       GlobalDomain,LocalDomain,iProcUnion,iCommUnion)

    !INPUT ARGUMENTS:
    type(DomainType),intent(inout)::GlobalDomain
    type(DomainType),&
         intent(in)::LocalDomain
    integer,intent(in),optional::iProcUnion,iCommUnion
    !EOP
    integer::iProc0,iComm,LocalIRealization,iError
    logical::IsSynchronized
    if(present(iProcUnion).and.present(iCommUnion))then
       iProc0=iProcUnion
       iComm=iCommUnion
    else
       iProc0=i_proc0(GlobalDomain%CompID_)
       iComm=i_comm()
    end if
    if(is_proc0(GlobalDomain%CompID_))&
         LocalIRealization=LocalDomain%iRealization

    call MPI_Bcast(LocalIRealization,&
         1,MPI_INTEGER,&
         iProc0, iComm,iError)
    call MPI_Allreduce(LocalIRealization==GlobalDomain%iRealization,&
         IsSynchronized,1,MPI_LOGICAL,MPI_LAND,iComm,iError)
    if(IsSynchronized)return
    if(is_proc0(GlobalDomain%CompID_))then
       GlobalDomain%iRealization=LocalDomain%iRealization
       GlobalDomain%nTreeNodes=LocalDomain%nTreeNodes
       call check_octree_grid_allocation(GlobalDomain)
       GlobalDomain%iDecomposition_II(:,1:GlobalDomain%nTreeNodes)=&
            LocalDomain%iDecomposition_II(:,1:LocalDomain%nTreeNodes)
    end if
    if(present(iProcUnion).and.present(iCommUnion))then
       call bcast_indexes_dd(GlobalDomain,&
            iProcUnion,iCommUnion)
    else
       call bcast_indexes_dd(GlobalDomain)
    end if
  end subroutine synchronize_refinement_dd
  !BOP
  !\begin{verbatim}
  !===============================================================
  !                                                               
  !                 METODS                                        
  !           ALL WITH INTERFACE                                  
  !===============================================================
  !The "methods" below show how to use the information available   
  !from grid descriptors.They involve some elements of the        
  !connectivity list for blocks and searching tools               
  !===============================================================
  !
  !================CONNECTIVITY LIST==============================
  !
  !\end{verbatim}
  !EOP
  !BOP
  !IROUTINE: is_left_boundary_d - if block boundary is domain boundary 
  !EOP
  !===============================================================
  !BOP
  !DESCRIPTION:
  !Returns the nDim vector, whose iDim's component is true, if    
  !along the iDim's direction there is a domain Boundary to the   
  !Left from the block with the number lGlobalTreeNumber          
  !EOP

  !BOP
  !INTERFACE:
  function is_left_boundary_dd(&
       Domain,lGlobalTreeNumber)
    !INPUT ARGUMENTS:
    integer,intent(in)::lGlobalTreeNumber
    type(DomainType),intent(in)::&
         Domain
    !OUTPUT ARGUMENTS:
    logical,dimension(Domain%nDim)::&
         is_left_boundary_dd
    !EOP
    is_left_boundary_dd=.not.(Domain%IsPeriodic_D)&
         .and.Domain%XyzBlock_DI(&
         :,lGlobalTreeNumber)<&
         cThird*Domain%DXyzBlock_DI(&
         :,lGlobalTreeNumber)+&
         Domain%XyzMin_D
  end function is_left_boundary_dd
  !===============================================================!
  !BOP:
  !IROUTINE: is_right_boundary_d - if block boundary is domain boundary
  !DESCRIPTION:
  !Returns the nDim vector, whose iDim's component is true, if    
  !along the iDim's direction there is a Tree Boundary to the     
  !Right from the block with the number lGlobalTreeNumber         
  !EOP
  !BOP

  !BOP
  !INTERFACE:
  function is_right_boundary_dd(&
       Domain,lGlobalTreeNumber)
    !INPUT ARGUMENTS:
    integer,intent(in)::lGlobalTreeNumber
    type(DomainType),intent(in)::&
         Domain
    logical,dimension(Domain%nDim)::&
         is_right_boundary_dd
    !EOP
    is_right_boundary_dd=.not.&
         (Domain%IsPeriodic_D).and.&
         Domain%XyzBlock_DI(:,lGlobalTreeNumber)+&
         (cOne+cThird)*Domain%DXyzBlock_DI(&
         :,lGlobalTreeNumber)>&
         Domain%XyzMax_D
  end function is_right_boundary_dd
  !===============================================================!
  !BOP
  !IROUTINE: l_neighbor - returns the number of neighboring block
  !DESCRIPTION:                                                              
  ! Tree neighbor                                                 
  ! returns the number of octree node, to which the center of the 
  !"ghost cell" belongs, which is marked with iCells\_D cell index 
  !vector. 
  !EOP

  !BOP
  !INTERFACE:
  integer function l_neighbor_dd(&
       Domain,lGlobalTreeNumber,iCells_D)
    !INPUT ARGUMENTS:
    integer,intent(in)::lGlobalTreeNumber
    type(DomainType),intent(inout)::&
         Domain
    integer,dimension(Domain%nDim),&
         intent(in)::iCells_D
    !EOP
    real,dimension(Domain%nDim)::Xyz_D
    if(any(is_left_boundary_dd( Domain,&
         lGlobalTreeNumber).and.iCells_D<1).or.&
         any(is_right_boundary_dd(Domain,&
         lGlobalTreeNumber).and.iCells_D>&
         Domain%nCells_D))then
       l_neighbor_dd=None_
    else
       !\
       ! Cell center coordinates
       Xyz_D = &
            Domain%XyzBlock_DI(:,lGlobalTreeNumber) + &
            Domain%DXyzCell_DI(:,lGlobalTreeNumber)*&
            (real(iCells_D) - 0.5)
       call search_in_dd(Domain, Xyz_D, l_neighbor_dd)
    end if
  end function l_neighbor_dd
  !==========================
  !BOP
  !INTERFACE:
  subroutine glue_margin_dd(&
       Domain,Xyz_D)
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    real,dimension(Domain%nDim),&
         intent(inout)::Xyz_D
    !-----------
    !\
    ! Loop variable:
    !/
    integer :: iDir, nDim
    !\
    ! Directions to be glued
    integer :: iDirMinusGlue, iDirPlusGlue, iDirCycle
    !\
    ! Domain boundaries:
    !/
    real,dimension(:),pointer::XyzMin_D,XyzMax_D
    logical :: DoCycle
    !-----------------
    nDim = Domain%nDim
    XyzMin_D => Domain%XyzMin_D
    XyzMax_D => Domain%XyzMax_D
    iDirCycle = Domain%iDirCycle
    iDirMinusGlue = Domain%iDirMinusGlue
    iDirPlusGlue = Domain%iDirPlusGlue
    DoCycle = iDirCycle > 0.and.iDirCycle <= nDim
    do iDir = 1, nDim
       if(iDir == iDirCycle)CYCLE
       if(Xyz_D(iDir) < XyzMin_D(iDir).and.iDir==iDirMinusGlue)then
          !Ruturn the coordinate along the glued direction to the domain
          Xyz_D(iDir) = 2*XyzMin_D(iDir) - Xyz_D(iDir)
          !Add, if needed a half cycle over cycled direction
          if(DoCycle)&
               Xyz_D(iDirCycle) = XyzMin_D(iDirCycle) + &
               modulo(Xyz_D(iDirCycle) + 0.50*&
                XyzMax_D(iDirCycle) - 1.50*XyzMin_D(iDirCycle),&
                XyzMax_D(iDirCycle) -  XyzMin_D(iDirCycle))
       elseif(Xyz_D(iDir) > XyzMax_D(iDir).and.iDir==iDirPlusGlue)then
          !Ruturn the coordinate along the glued direction to the domain
          Xyz_D(iDir) = 2*XyzMax_D(iDir) - Xyz_D(iDir)
          !Add, if needed a half cycle over cycled direction
          if(DoCycle)&
               Xyz_D(iDirCycle) = XyzMin_D(iDirCycle) + &
               modulo(Xyz_D(iDirCycle) + 0.50*&
               XyzMax_D(iDirCycle) - 1.50*XyzMin_D(iDirCycle),&
               XyzMax_D(iDirCycle) -  XyzMin_D(iDirCycle))
       end if
    end do
  end subroutine glue_margin_dd
  !BOP
  !IROUTINE: search_in - find which block involves the given point
  !DESCRIPTION:
  !\begin{verbatim}
  !===============================================================
  !=====================SEARCH====================================
  !===============================================================
  !The searching tools start from here which allow to find the    
  !location in the domain decomposition, using the generalized    
  !  coordinates of the point.                                    
  !===============================================================
  !                                                              
  !Returns lGlobalTreeNumber, which is the  global number of the  
  !block which includes the point Xyz_D.                          
  !The starting values for Xyz_D should be the generalized        
  !coordinates for the point, finally in this array there are the 
  !coordinates with respect to the left corner of the found block. 
  !The values of Xyz_D are allowed to be outside of the domain,   
  !the nearest block is found in this case.
  !\end{verbatim}  
  !EOP                     

  !BOP
  !INTERFACE:
  subroutine search_in_dd(&
       Domain,Xyz_D,lGlobalTreeNumber)
    !INPUT ARGUMENTS:
    type(DomainType),intent(inout)::&
         Domain
    real,dimension(Domain%nDim),&
         intent(inout)::Xyz_D
    !OUTPUT ARGUMENTS:
    integer,intent(out)::lGlobalTreeNumber
    !EOP
    real,dimension(Domain%nDim)::&
         XyzTrunc_D,Discr_D
    integer,dimension(Domain%nDim)::&
         iRootMinusOne_D,iRootMinusOneStart_D
    integer,dimension(Domain%nDimTree)::iShift_D
    integer::iChild,iDim,lFound

    !Start from the result of the previous search
    lFound=Domain%lSearch

    !Put the point inside the domain
    do iDim=1,Domain%nDim
       if(.not.Domain%IsPeriodic_D(iDim))CYCLE
       Xyz_D(iDim)=Domain%XyzMin_D(iDim)+&
            modulo(Xyz_D(iDim)-Domain%XyzMin_D(iDim),&
         Domain%XyzMax_D(iDim)-&
         Domain%XyzMin_D(iDim))
    end do
    XyzTrunc_D=Domain%XyzMin_D+&
         max(cZero,min(Xyz_D-Domain%XyzMin_D,&
         cAlmostOne*(Domain%XyzMax_D-&
         Domain%XyzMin_D)))

    Discr_D=(XyzTrunc_D-Domain%XyzBlock_DI(&
         :,lFound))/Domain%DXyzBlock_DI(:,lFound)

    !Recursive search starts
    do

       ! correct Discr_D to avoid having points exactly
       ! on the boundary of a block; potentiall introduces error,
       ! but it would matter -log_2(cTol)~23 resolution level up the tree
       Discr_D = real(floor(Discr_D)) + &
            min( cAlmostOne, max( cTol2, Discr_D-real(floor(Discr_D)) ) )

       if(any(Discr_D<cZero).or.any(Discr_D>=cOne))then
          iChild=Domain%iDecomposition_II(&
               MyNumberAsAChild_,lFound)
          if(iChild==0)then  !This is a root

             iRootMinusOneStart_D=&
                  nint((Domain%XyzBlock_DI(&
                  :,lFound)-Domain%XyzMin_D)&
                  /Domain%DXyzBlock_DI(:,lFound))
             !Calculate iRoot-1,jRoot-1....
             iRootMinusOne_D=floor(Discr_D)+&
                  iRootMinusOneStart_D
             Discr_D=Discr_D-floor(Discr_D)
             !Calculate the root number, using the formula 
             !lRoot-1=iRoot-1+&
             !(jRoot-1)*RootMapDim(1)+&
             !(kRoot-1)*RootMapDim(1)*RootMapDim(2)
             lFound=1+iRootMinusOne_D(1)
             do iDim=2,Domain%nDim
                lFound=lFound+iRootMinusOne_D(iDim)*&
                     product(&
                     Domain%iRootMapDim_D(1:iDim-1))
             end do
             if(Domain%IsTreeDecomposition)&
                  lFound=Domain%iRoot_I(lFound)
          else     !End of computations for root
             !---------------------------------------------------------------!
             !Descend the octree                                             !
             lFound=Domain%iDecomposition_II(&
                  Parent_,lFound)
             Discr_D(1:Domain%nDimTree)=&
                  (Discr_D(1:Domain%nDimTree)+&
                  real(Domain%iShift_DI(&
                  :,iChild)))* 0.50
          end if
       elseif&
            (is_used_block_dd(Domain,lFound))then
          EXIT ! Octree node is found
       else
          !---------------------------------------------------------------!
          !Ascend the octree: calculate the shift                         !
          Discr_D(1:Domain%nDimTree)=&
               Discr_D(1:Domain%nDimTree)&
               *2.0
          iShift_D=int(Discr_D(&
               1:Domain%nDimTree))
          Discr_D(1:Domain%nDimTree)=&
               Discr_D(1:Domain%nDimTree)-&
               real(iShift_D)
          !---------------------------------------------------------------!
          !Choose the child to ascend to                                  !
          iChild=1
          do while (any(iShift_D/=&
               Domain%iShift_DI(:,iChild)))
             iChild=iChild+1
          end do
          lFound=Domain%iDecomposition_II(&
               iChild,lFound)
       end if
    end do
    !---------------------------------------------------------------!
    !End of recursive search                                        !
    Xyz_D=Xyz_D-Domain%XyzBlock_DI(:,lFound)
    lGlobalTreeNumber=lFound
    Domain%lSearch=lFound
  end subroutine search_in_dd
  !===============================================================!
  !BOP
  !IROUTINE: search_cell - find cell which includes a given point
  !DESCRIPTION:
  !In searching the cell the original values of the generalized   
  !coordinates must be defined with respect to the left corner and
  !a global tree node number should be known                      
  !search\_cell ALWAYS returns the position of the Xyz point with  
  !respect to the found cell left corner.                         
  !                                                               
  ! The best order to find cell number for a position of point    
  !If the block number is needed                                  
  !\begin{verbatim}                                               
  !call search_in(Domain,Xyz_D,lFound),              
  !iBlock=blk_decomposition(Domain,lFound)           
  !call search_cell(Domain,Xyz_D,lFound,Cells_D)     
  !\end{verbatim}
  !the second step can be missed if the block number is not needed
  !The input Xyz\_D can be outside the domain,                     
  !covered by grid, in this case the values of the cell           
  !can be less than unity or greater that nCells\_D. This use is   
  !not restricted, because the cell to find may be the ghostcell.
  !EOP 
  !---------------------------------------------------------------

  !BOP
  !INTERFACE:
  subroutine search_cell_dd(&
       Domain,lGlobalTreeNumber,Xyz_D,iCells_D)
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    real,dimension(Domain%nDim),&
         intent(inout)::Xyz_D
    integer,intent(in)::lGlobalTreeNumber
    !OUTPUT ARGUMENTS:
    integer,dimension(Domain%nDim),&
         intent(out)::iCells_D
    !EOP
    real,dimension(Domain%nDim)::DXyzCells_D
    DXyzCells_D=Domain%DXyzCell_DI(&
         :,lGlobalTreeNumber)
    iCells_D=floor(Xyz_D/DXyzCells_D)
    Xyz_D=Xyz_D-DXyzCells_D*iCells_D
    iCells_D=iCells_D+1
  end subroutine search_cell_dd
  !---------------------------------------------------------------!

  !BOP
  !IROUTINE: pe_and_blk - return PE and/or block local number

  !DESCRIPTION:
  !Block and pe as a fucntion of lGlobalNumber. 
  !Use subroutine pe\_and\_blk or functions pe\_decomposition
  !and blk\_decomposition
  !EOP               


  !BOP
  !INTERFACE:
  integer function pe_dd(&
       Domain,lGlobalTreeNumber)
    !INPUT ARGUMENTS: 
    type(DomainType),intent(in)::&
         Domain
    integer,intent(in)::lGlobalTreeNumber
    !EOP
    pe_dd=Domain%iDecomposition_II(&
         PE_,lGlobalTreeNumber)
  end function  pe_dd
  !---------------------------------------------------------------!
  !BOP
  !INTERFACE:
  integer function blk_dd(&
       Domain,lGlobalTreeNumber)
    !INPUT ARGUMENTS: 
    type(DomainType),intent(in)::&
         Domain
    integer,intent(in)::lGlobalTreeNumber
    !EOP
    blk_dd=Domain%iDecomposition_II(&
         BLK_,lGlobalTreeNumber)
  end function blk_dd
  !---------------------------------------------------------------!
  !BOP:
  !INTERFACE:
  subroutine pe_and_blk_dd(&
       Domain,lGlobalTreeNumber,iPEOut,iBlockOut)
    !INPUT ARGUMENTS: 
    type(DomainType),intent(in)::&
         Domain
    integer,intent(in)::lGlobalTreeNumber
    !OUTPUT ARGUMENTS
    integer,intent(out)::iPEOut,iBlockOut
    !EOP
    iPEOut=Domain%iDecomposition_II(&
         PE_,lGlobalTreeNumber)
    iBlockOut=Domain%iDecomposition_II(&
         BLK_,lGlobalTreeNumber)
  end subroutine pe_and_blk_dd
  !BOP
  !IROUTINE: n_block,n_block_total - number of blocks at given PE and total

  !BOP
  !INTERFACE:
  integer function n_block_dd(&
       Domain,iPE)
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    !EOP
    integer,intent(in)::iPE
    n_block_dd=count(&
         Domain%iDecomposition_II(&
         FirstChild_,1:Domain%nTreeNodes)&
         ==None_.and.&
         Domain%iDecomposition_II(&
         PE_,1:Domain%nTreeNodes)==iPE)
  end function n_block_dd
  !---------------------------------------------------------------!
  !BOP
  !INTERFACE:
  integer function n_block_total_dd(&
       Domain)
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    !EOP
    n_block_total_dd=Domain%nBlockAll
  end function n_block_total_dd
  !===============================================================!
  !BOP
  !IROUTINE: min_block,min_block_pe,max_block,max_block_pe
  !DESCRIPTION:
  !Minimal and maximal block number.
  !Throughout all PEs or for a given processor
  !EOP

  !BOP
  !INTERFACE:
  integer function min_block_pe_dd(&
       Domain,iPE)
    !INPUT ARGUMENTS: 
    type(DomainType),intent(in)::&
         Domain
    integer,intent(in)::iPE
    !EOP
    min_block_pe_dd=minval(&
         Domain%iDecomposition_II(&
         BLK_,1:Domain%nTreeNodes),MASK=&
         Domain%iDecomposition_II(&
         FirstChild_,1:Domain%nTreeNodes)==None_&
         .and. Domain%iDecomposition_II(&
         PE_,1:Domain%nTreeNodes)==iPE)
  end function min_block_pe_dd
  !---------------------------------------------------------------!
  !BOP
  !INTERFACE:
  integer function max_block_pe_dd(&
       Domain,iPE) 
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    integer,intent(in)::iPE
    !EOP
    max_block_pe_dd=maxval(&
         Domain%iDecomposition_II(&
         BLK_,1:Domain%nTreeNodes),MASK=&
         Domain%iDecomposition_II(&
         FirstChild_,1:Domain%nTreeNodes)==None_&
         .and. Domain%iDecomposition_II(&
         PE_,1:Domain%nTreeNodes)==iPE)
  end function max_block_pe_dd
  !---------------------------------------------------------------!
  !BOP
  !INTERFACE:
  integer function min_block_dd(&
       Domain) 
    type(DomainType),intent(in)::&
         Domain
    !EOP
    min_block_dd=Domain%MinBlock
  end function min_block_dd
  !---------------------------------------------------------------!
  !BOP
  !INTERFACE:
  integer function max_block_dd(&
       Domain) 
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    !EOP
    max_block_dd=Domain%MaxBlock

  end function max_block_dd
  !---------------------------------------------------------------!
  integer function iglobal_bp_dd(Domain,iBLK,iPE)
    type(DomainType),intent(in)::Domain
    integer,intent(in)::iBLK,iPE
    iglobal_bp_dd=Domain%iGlobal_BP(iBLK,iPE)
  end function iglobal_bp_dd
  !---------------------------------------------------------------!
  integer function iglobal_node_dd(Domain,iBlockAll)
    type(DomainType),intent(in)::Domain
    integer,intent(in)::iBlockAll
    iglobal_node_dd=Domain%iGlobal_A(iBlockAll)
  end function iglobal_node_dd
  !---------------------------------------------------------------!
  integer function iglobal_block_dd(&
       Domain,iGlobalTreeNode)
    type(DomainType),intent(in)::Domain
    integer,intent(in)::iGlobalTreeNode
    iglobal_block_dd=Domain%iDecomposition_II(&
         GlobalBlock_,iGlobalTreeNode)
  end function iglobal_block_dd
  !---------------------------------------------------------------!
  logical function used_bp_dd(Domain,iBLK,iPE)
    type(DomainType),intent(in)::Domain
    integer,intent(in)::iBLK,iPE
    integer,dimension(2)::iUpper_I,iLower_I

    iUpper_I=ubound(Domain%iGlobal_BP)
    iLower_I=lbound(Domain%iGlobal_BP)

    used_bp_dd=.false.
    if(  iBLK>=iLower_I(1).and.&
         iBLK<=iUpper_I(1).and.&
         iPE >=iLower_I(2).and.&
         iPE <=iUpper_I(2)    )&
         used_bp_dd=Domain%iGlobal_BP(iBLK,iPE)/=None_
  end function used_bp_dd
  !---------------------------------------------------------------!
  
  subroutine set_lsearch_dd(Domain,iGlobal)
    type(DomainType),intent(inout)::Domain
    integer,intent(in)::iGlobal
    Domain%lSearch=iGlobal
  end subroutine set_lsearch_dd
 
  !BOP
  !IROUTINE: access to decomposition elements: compid_grid (component ID)
  !DESCRIPTION:
  !\begin{verbatim}
  !===============================================================!
  !===============================================================!
  !             Access to the elements of the structures          !
  !===============================================================!
  !\end{verbatim}
  !EOP

  !BOP
  !INTERFACE:
  integer function compid_grid_dd(Domain)
    !INPUT ARGUMENTS
    type(DomainType),intent(in)::&
         !EOP
    Domain
    compid_grid_dd=Domain%CompID_
  end function compid_grid_dd

  !BOP
  !INTERFACE:
  integer function ndim_grid_dd(Domain)
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    !EOP
    nDim_grid_dd=Domain%nDim
  end function ndim_grid_dd
  !===============================================================!
  !BOP
  !IROUTINE: access to decomposition elements: xyz_min_d 

  !BOP
  !INTERFACE:
  function xyz_min_grid_dd(Domain)
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    !OUTPUT ARGUMENTS:
    real,dimension(Domain%nDim)::xyz_min_grid_dd
    !EOP
    xyz_min_grid_dd=Domain%XyzMin_D
  end function xyz_min_grid_dd
  !===============================================================!
  !BOP
  !IROUTINE: access to decomposition elements: xyz_max_d

  !BOP
  !INTERFACE:
  function xyz_max_grid_dd(Domain)
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    !OUTPUT ARGUMENTS:
    real,dimension(Domain%nDim)::xyz_max_grid_dd
    !EOP
    xyz_max_grid_dd=Domain%XyzMax_D
  end function xyz_max_grid_dd
  !===============================================================!
  !BOP
  !IROUTINE: access to decomposition elements: root_map_d

  !BOP
  !INTERFACE:
  function root_map_dd(Domain)
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    !OUTPUT ARGUMENTS:
    real,dimension(Domain%nDim)::root_map_dd
    !EOP
    root_map_dd=Domain%iRootMapDim_D
  end function root_map_dd
  !===============================================================!
  !BOP
  !IROUTINE: access to decomposition elements: ncells_decomposition

  !BOP
  !INTERFACE:
  function ncells_grid_dd(Domain)
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    !OUTPUT ARGUMENTS:
    real,dimension(Domain%nDim)::ncells_grid_dd
    !EOP
    ncells_grid_dd=Domain%nCells_D
  end function ncells_grid_dd
  !===============================================================!
  !BOP
  !IROUTINE: access to decomposition elements: ntree_nodes

  !BOP
  !INTERFACE:
  integer function ntree_nodes_dd(Domain)
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    !EOP
    ntree_nodes_dd=Domain%nTreeNodes
  end function ntree_nodes_dd
  !===============================================================!
  !BOP
  !IROUTINE: xyz_block_d - the coordinates of the block left corner

  !BOP
  !INTERFACE:
  function xyz_block_dd(&
       Domain,lGlobalTreeNumber)
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    integer,intent(in)::lGlobalTreeNumber
    !OUTPUT ARGUMENTS:
    real,dimension(Domain%nDim)::xyz_block_dd
    !EOP
    xyz_block_dd=Domain%XyzBlock_DI(&
         :,lGlobalTreeNumber)
  end function xyz_block_dd
  !===============================================================!
  !BOP
  !IROUTINE: d_xyz_block_d - block sizes

  !BOP
  !INTERFACE:
  function d_xyz_block_dd(&
       Domain,lGlobalTreeNumber)
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    integer,intent(in)::lGlobalTreeNumber
    !OUTPUT ARGUMENTS:
    real,dimension(Domain%nDim)::d_xyz_block_dd
    !EOP
    d_xyz_block_dd=Domain%DXyzBlock_DI(&
         :,lGlobalTreeNumber)
  end function d_xyz_block_dd
  !===============================================================!
  !BOP
  !IROUTINE: d_xyz_cell_d - cell sizes

  !BOP
  !INTERFACE:
  function d_xyz_cell_dd(&
       Domain,lGlobalTreeNumber)
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    integer,intent(in)::lGlobalTreeNumber
    !OUTPUT ARGUMENTS:
    real,dimension(Domain%nDim)::d_xyz_cell_dd
    !EOP
    d_xyz_cell_dd=Domain%DXyzCell_DI(&
         :,lGlobalTreeNumber)
  end function d_xyz_cell_dd

  !===============================================================!
  !BOP
  !IROUTINE: is_used_block - if it is data block or intermediate tree node

  !BOP
  !INTERFACE:
  logical function is_used_block_dd(&
       Domain,lGlobalTreeNumber)
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    integer,intent(in)::lGlobalTreeNumber
    !EOP
    is_used_block_dd=&
         Domain%iDecomposition_II(&
         FirstChild_,lGlobalTreeNumber)==None_
  end function is_used_block_dd

  !===============================================================!

  logical function is_root_node_dd(&
       Domain,lGlobalTreeNumber)
    type(DomainType),intent(in)::&
         Domain
    integer,intent(in)::lGlobalTreeNumber
    is_root_node_dd=&
         Domain%iDecomposition_II(&
         MyNumberAsAChild_,lGlobalTreeNumber)==0
  end function is_root_node_dd
  !===============================================================!
  !BOP
  !IROUTINE: i_realization - determine if the AMR decomposition is new

  !BOP
  !INTERFACE:
  integer function irealization_dd(Domain)
    !INPUT ARGUMENTS:
    type(DomainType),intent(in)::&
         Domain
    !EOP
    irealization_dd=Domain%iRealization
  end function irealization_dd

  !===============================================================!

  logical function is_local_grid_dd(Domain)
    type(DomainType),intent(in)::&
         Domain
    is_local_grid_dd=Domain%IsLocal
  end function is_local_grid_dd
  !===============================================================!
  logical function is_tree_dd(Domain)
    type(DomainType),intent(in)::&
         Domain
    is_tree_dd=Domain%IsTreeDecomposition
  end function is_tree_dd
  !===============================================================!
  subroutine associate_dd_pointer_dd(&
       Domain,DomainPointer)
    Type(DomainType),target,intent(in)::&
         Domain
    type(DomainPointerType),intent(out)::DomainPointer
    nullify(DomainPointer%Ptr)
    DomainPointer%Ptr=>Domain
  end subroutine associate_dd_pointer_dd
  !==============================END==============================!
end Module CON_domain_decomposition

!BOP
!IROUTINE: more methods
!DESCRIPTION:
!More methods are available: see the source file.
!EOP
