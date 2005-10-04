!^CFG COPYRIGHT UM
!==========================================================================
!==========================================================================
!==========================================================================
module ModMPNodes

  use ModMain, ONLY : nI,nJ,nK, nBLK, iNewGrid, iNewDecomposition

  implicit none

  save

  integer :: numSendRecv, numSend, numRecv, numCopy
  integer :: numSendRecvMax=0, numSendMax=0, numRecvMax=0, numCopyMax=0

  integer, dimension(:),   allocatable :: &
       nSend, nRecv, nSendStart, nRecvStart
  integer, dimension(:,:), allocatable :: &
       VSendI, VRecvI, VSendIlocal, VRecvIlocal

  integer, dimension(1:nI+1,1:nJ+1,1:nK+1,nBLK) :: NodeCount
  real,    dimension(1:nI+1,1:nJ+1,1:nK+1,nBLK,8) :: V

  real,    dimension(:),   allocatable :: VSend, VRecv

  integer :: iLastGrid = -1, iLastDecomposition = -1
  integer :: itag, lS(0:7), lR(5), nSends
  integer, parameter :: maxMessages=10000
  integer :: nVar=99999

  logical, parameter :: DoLimitCornerMemory=.true.
  logical, parameter :: DoRSend=.true.
  logical, parameter :: DoBreakUpMessages=.false.
  logical, parameter :: DoImplicitUnusedBlock=.false.

end module ModMPNodes

!==========================================================================
!==========================================================================
!==========================================================================
subroutine message_pass_nodes
  !
  ! This routine will complete a messagepass of variable V.
  !   It will pass all node values where a neighbor in that
  !   direction exists.  This includes refinement level changes and
  !   fills face values and optionally edge and corner values.
  !
  use ModProcMH
  use ModMPNodes
  use ModNumConst
  use ModMpi
  implicit none

  !Local variables
  real :: Counter
  integer :: i,j,k, iV,iBLK, iPE, iError
  integer :: nSENDrequests, SENDrequests(maxMessages)
  integer :: nRECVrequests, RECVrequests(maxMessages)
  integer :: MESGstatus(MPI_STATUS_SIZE, maxMessages)

  !------------------------------------------

  ! Check that indices are up to date
  if(iNewGrid/=iLastGrid .or. iNewDecomposition/=iLastDecomposition) &
       call mp_nodes_set_indices

  ! When neighbor is on the same processor, Collect/Send/Assign are all
  !    done in one step, without intermediate memory use.
  iPE=iProc
  do iV=1,nSend(iPE)
     lS(:)=VSendIlocal(:,iV)
     lR(:)=VRecvIlocal(:,iV)
     V(lR(1),lR(2),lR(3),lR(4),lR(5)) = V(lS(1),lS(3),lS(5),lS(7),1)
  end do

  ! Collect values into VSend that need to be passed to other processors
  do iPE=0,nProc-1
     if(iPE==iProc) CYCLE
     if(nSend(iPE)==0) CYCLE
     do iV=nSendStart(iPE)+1,nSendStart(iPE)+nSend(iPE)
        lS(:)=VSendI(:,iV)
        VSend(iV) = V(lS(1),lS(3),lS(5),lS(7),1)
     end do
  end do

  ! Post receives first so that they are ready
  nRECVrequests = 0  
  do iPE=0,nProc-1
     if(iPE == iProc) CYCLE
     if(nRecv(iPE)==0) CYCLE
     if(DoBreakUpMessages)then
        nSends=1+((nRecv(iPE)-1)/nVar)
        do i=1,nSends
           itag = nProc*(i-1)+iPE
           nRECVrequests = nRECVrequests + 1
           if(nRECVrequests>maxMessages) call stop_mpi("Too many RECVs in mp_SendValues")
           call MPI_irecv(VRecv(nRecvStart(iPE)+1+((i-1)*nVar)),min(nVar,nRecv(iPE)-((i-1)*nVar)), &
                MPI_REAL,iPE,itag,iComm,RECVrequests(nRECVrequests),iError)
        end do
     else
        itag = iPE
        nRECVrequests = nRECVrequests + 1
        if(nRECVrequests>maxMessages) call stop_mpi("Too many RECVs in mp_SendValues")
        call MPI_irecv(VRecv(nRecvStart(iPE)+1),nRecv(iPE), &
             MPI_REAL,iPE,itag,iComm,RECVrequests(nRECVrequests),iError)
     end if
  end do

  ! Make sure all recv's are posted before using an rsend
  if(DoRSend)then
     call MPI_BARRIER(iComm,iError) ! ----------- BARRIER ------
  end if

  ! VSend array sent to VRecv array on other PEs
  nSENDrequests = 0
  do iPE=0,nProc-1
     if(iPE == iProc) CYCLE
     if(nSend(iPE)==0) CYCLE
     if(DoBreakUpMessages)then
        nSends=1+((nSend(iPE)-1)/nVar)
        do i=1,nSends
           itag = nProc*(i-1)+iProc
           if(DoRSend)then
              call MPI_rsend(VSend(nSendStart(iPE)+1+((i-1)*nVar)),min(nVar,nSend(iPE)-((i-1)*nVar)), &
                   MPI_REAL,iPE,itag,iComm,iError)
           else
              nSENDrequests = nSENDrequests + 1
              call MPI_isend(VSend(nSendStart(iPE)+1+((i-1)*nVar)),min(nVar,nSend(iPE)-((i-1)*nVar)), &
                   MPI_REAL,iPE,itag,iComm,SENDrequests(nSENDrequests),iError)
           end if
        end do
     else
        itag = iProc
        if(DoRSend)then
           call MPI_rsend(VSend(nSendStart(iPE)+1),nSend(iPE), &
                MPI_REAL,iPE,itag,iComm,iError)
        else
           nSENDrequests = nSENDrequests + 1
           call MPI_isend(VSend(nSendStart(iPE)+1),nSend(iPE), &
                MPI_REAL,iPE,itag,iComm,SENDrequests(nSENDrequests),iError)
        end if
     end if
  end do

  ! Wait for messages to be received before continuing.
  call MPI_waitall(nRECVrequests, RECVrequests(1), MESGstatus(1,1), iError)

  ! This loop copies the values from VRecv to their destination
  do iPE=0,nProc-1
     if(iPE==iProc) CYCLE
     if(nRecv(iPE)==0) CYCLE
     do iV=nRecvStart(iPE)+1,nRecvStart(iPE)+nRecv(iPE)
        lR(:)=VRecvI(:,iV)
        V(lR(1),lR(2),lR(3),lR(4),lR(5)) = VRecv(iV)
     end do
  end do

  ! Wait for sent messages to be received before exiting
  if(.not.DoRSend)then
     call MPI_waitall(nSENDrequests, SENDrequests(1), MESGstatus(1,1), iError)
  end if

end subroutine message_pass_nodes

!==========================================================================
!==========================================================================
!==========================================================================
subroutine mp_nodes_set_indices
  !
  !
  use ModProcMH
  use ModMPNodes
  use ModMpi
  implicit none

  !Local variables
  integer :: iPE, iError
  !------------------------------------------

  iLastGrid          = iNewGrid
  iLastDecomposition = iNewDecomposition

  ! Initialize count back to 1, then increase as needed
  nodeCount = 1

  call mp_allocate_node_arrays1
  call mp_build_node_indices(.true.)

  call mp_allocate_node_arrays2
  call mp_build_node_indices(.false.)

  call MPI_BARRIER(iComm,iError) ! ----------- BARRIER ------


contains

  !==========================================================================
  subroutine mp_allocate_node_arrays1
    !
    ! Allocate initial arrays for counting the number of sends and receives
    !

    !------------------------------------------

    ! Allocate new memory only if not already allocated, then initialize

    if(.not.allocated(nSend))then
       allocate( nSend(0:nProc-1), stat=iError ); call alloc_check(iError,"nSend")
    end if
    nSend=0

    if(.not.allocated(nRecv))then
       allocate( nRecv(0:nProc-1), stat=iError ); call alloc_check(iError,"nRecv")
    end if
    nRecv=0

    if(.not.allocated(nSendStart))then
       allocate( nSendStart(0:nProc-1), stat=iError ); call alloc_check(iError,"nSendStart")
    end if
    nSendStart=0

    if(.not.allocated(nRecvStart))then
       allocate( nRecvStart(0:nProc-1), stat=iError ); call alloc_check(iError,"nRecvStart")
    end if
    nRecvStart=0
    
  end subroutine mp_allocate_node_arrays1

  !==========================================================================
  subroutine mp_allocate_node_arrays2
    !
    ! Allocate arrays to hold the index mapping and send/recv values based on
    !    how many sends/recvs are needed
    !

    !------------------------------------------

    numCopy=nSend(iProc)
    numSend=sum(nSend)-nSend(iProc)
    numRecv=sum(nRecv)-nRecv(iProc)
    numSendRecv = max(1,max(numSend,numRecv))

    nSendStart=0
    nRecvStart=0
    do iPE=0,nProc-2
       if(iPE==iProc)then
          nSendStart(iPE+1)=nSendStart(iPE)
          nRecvStart(iPE+1)=nRecvStart(iPE)
       else
          nSendStart(iPE+1)=nSendStart(iPE)+nSend(iPE)
          nRecvStart(iPE+1)=nRecvStart(iPE)+nRecv(iPE)
       end if
    end do

!!$    write(*,*)'MPN: PE=',iProc,' SEND:',nSend,' RECV:',nRecv,' SUMMARY:',numSend,numRecv,numCopy

    ! Re-Allocate memory if past use was not large enough

    if(  numSendRecv > numSendRecvMax .or. &
         numSend     > numSendMax     .or. &
         numRecv     > numRecvMax     .or. &
         numCopy     > numCopyMax           )then

       ! Deallocate old memory and allocate new memory

       if(allocated(VSendI)) deallocate(VSendI)
       allocate( VSendI(0:7,numSendRecv), stat=iError ); call alloc_check(iError,"VSendI")

       if(allocated(VRecvI)) deallocate(VRecvI)
       allocate( VRecvI(5,numSendRecv), stat=iError ); call alloc_check(iError,"VRecvI")

       if(allocated(VSendIlocal)) deallocate(VSendIlocal)
       allocate( VSendIlocal(0:7,numCopy), stat=iError ); call alloc_check(iError,"VSendIlocal")

       if(allocated(VRecvIlocal)) deallocate(VRecvIlocal)
       allocate( VRecvIlocal(5,numCopy), stat=iError ); call alloc_check(iError,"VRecvIlocal")

       if(allocated(VSend )) deallocate(VSend )
       allocate( VSend(numSend), stat=iError ); call alloc_check(iError,"VSend")

       if(allocated(VRecv )) deallocate(VRecv )
       allocate( VRecv(numRecv), stat=iError ); call alloc_check(iError,"VRecv")

       ! Update new max values

       numCopyMax = numCopy
       numSendMax = numSend
       numRecvMax = numRecv
       numSendRecvMax = numSendRecv

    end if

    ! Initialize memory

    VSendI=-9
    VRecvI=-9
    VSendIlocal=-9
    VRecvIlocal=-9
    VSend=0
    VRecv=0

  end subroutine mp_allocate_node_arrays2

end subroutine mp_nodes_set_indices

!==========================================================================
!==========================================================================
!==========================================================================
subroutine mp_build_node_indices(JustCount)
  !
  !
  use ModProcMH
  use ModOctree
  use ModMPNodes
  use ModAMR, ONLY : unusedBlock_BP
  implicit none

  !Subroutine arguements
  logical, intent(in) :: JustCount

  !Local variables
  integer :: iBLK,iPE, iCHILD, idir, sSubF,rSubF
  integer :: i1S,i2S, j1S,j2S, k1S,k2S, i1R,i2R, j1R,j2R, k1R,k2R

  integer, dimension(26) :: nsubF
  integer, dimension(26,3) :: dLOOP
  integer, dimension(26,8) :: subfaceNumber

  integer :: neighborLEV
  integer, dimension(4) :: neighborPE,neighborBLK,neighborCHILD
  !------------------------------------------

  ! face=1-6, edge=7-18, corner=19-26
  !    1   2   3   4   5   6    7   8   9  10  11  12  13  14  15  16  17  18   19  20  21  22  23  24  25  26
  !    W   E   N   S   T   B   WN  ES  WS  EN  NT  SB  NB  ST  TW  BE  TE  BW  WNT ESB WNB EST WST ENB WSB ENT
  data nsubF / &
       4,  4,  4,  4,  4,  4,   2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,   1,  1,  1,  1,  1,  1,  1,  1 /

  data dLOOP / &
       1, -1,  0,  0,  0,  0,   1, -1,  1, -1,  0,  0,  0,  0,  1, -1, -1,  1,   1, -1,  1, -1,  1, -1,  1, -1, &
       0,  0,  1, -1,  0,  0,   1, -1, -1,  1,  1, -1,  1, -1,  0,  0,  0,  0,   1, -1,  1, -1, -1,  1, -1,  1, &
       0,  0,  0,  0,  1, -1,   0,  0,  0,  0,  1, -1, -1,  1,  1, -1,  1, -1,   1, -1, -1,  1,  1, -1, -1,  1 /

  data subfaceNumber / &
       0,  2,  0,  2,  1,  0,   0,  2,  0,  0,  0,  0,  0,  1,  0,  0,  1,  0,   0,  0,  0,  1,  0,  0,  0,  0, &
       2,  0,  0,  4,  2,  0,   0,  0,  2,  0,  0,  0,  0,  2,  1,  0,  0,  0,   0,  0,  0,  0,  1,  0,  0,  0, &
       1,  0,  0,  3,  0,  2,   0,  0,  1,  0,  0,  2,  0,  0,  0,  0,  0,  1,   0,  0,  0,  0,  0,  0,  1,  0, &
       0,  1,  0,  1,  0,  1,   0,  1,  0,  0,  0,  1,  0,  0,  0,  1,  0,  0,   0,  1,  0,  0,  0,  0,  0,  0, &
       0,  3,  1,  0,  0,  3,   0,  0,  0,  1,  0,  0,  1,  0,  0,  2,  0,  0,   0,  0,  0,  0,  0,  1,  0,  0, &
       3,  0,  3,  0,  0,  4,   1,  0,  0,  0,  0,  0,  2,  0,  0,  0,  0,  2,   0,  0,  1,  0,  0,  0,  0,  0, &
       4,  0,  4,  0,  4,  0,   2,  0,  0,  0,  2,  0,  0,  0,  2,  0,  0,  0,   1,  0,  0,  0,  0,  0,  0,  0, &
       0,  4,  2,  0,  3,  0,   0,  0,  0,  2,  1,  0,  0,  0,  0,  0,  2,  0,   0,  0,  0,  0,  0,  0,  0,  1 /
  !------------------------------------------

  nSend=0
  nRecv=0

  do iPE = 0,nProc-1
     do iBLK = 1,nBLK
        if (.not.associated(global_block_ptrs(iBLK, iPE+1) % ptr)) CYCLE

        if (.not.global_block_ptrs(iBLK, iPE+1) % ptr % used) CYCLE

        if (DoImplicitUnusedBlock)then
           if (unusedBlock_BP(iBLK,iPE)) CYCLE
        end if

        !valid used block found, setup indices
        iCHILD = global_block_ptrs(iBLK, iPE+1) % ptr % child_number

           do idir=1,26
              call treeNeighbor(iPE,iBLK,dLOOP(idir,1),dLOOP(idir,2),dLOOP(idir,3), &
                   neighborPE,neighborBLK,neighborCHILD,neighborLEV)

              select case(neighborLEV)
              case(0)
                 !Build indices for send to same block level
                 sSubF=0
                 call build_i
              case(1)
                 !Build indices for send to coarser block level
                 sSubF=-1
                 call build_i
              case(-1)
                 !Build indices for send to finer block level
                 do sSubF=1,nsubF(idir)
                    call build_i
                 end do
              end select
           end do
     end do
  end do


contains

  !==========================================================================
  subroutine build_i
    !
    !

    !Local variables
    integer :: i,j,k, n
    integer :: nborPE, nborBLK

    !------------------------------------------

    nborPE  = neighborPE (max(1,sSubF))
    nborBLK = neighborBLK(max(1,sSubF))

    if (DoImplicitUnusedBlock)then
       if (unusedBlock_BP(nborBLK,nborPE)) return
    end if

    rSubF=0
    if(sSubF == -1) rSubF = subfaceNumber(idir,iCHILD)

    call set_indices
    if(sSubF == 0)then !Send to same level

       if(iProc == iPE)then
          do i=i1S,i2S; do j=j1S,j2S; do k=k1S,k2S
             nSend(nborPE)=nSend(nborPE)+1
             if(JustCount) CYCLE

             if(iPE==nborPE)then
                n=nSend(nborPE)
                VSendIlocal(0,n)=1
                VSendIlocal(1,n)=i; VSendIlocal(3,n)=j; VSendIlocal(5,n)=k
                VSendIlocal(2,n)=i; VSendIlocal(4,n)=j; VSendIlocal(6,n)=k
                VSendIlocal(7,n)=iBLK
             else
                n=nSendStart(nborPE)+nSend(nborPE)
                VSendI(0,n)=1
                VSendI(1,n)=i; VSendI(3,n)=j; VSendI(5,n)=k
                VSendI(2,n)=i; VSendI(4,n)=j; VSendI(6,n)=k
                VSendI(7,n)=iBLK
             end if
          end do; end do; end do
       end if
       if(iProc == nborPE)then
          do i=i1R,i2R; do j=j1R,j2R; do k=k1R,k2R
             nRecv(iPE)=nRecv(iPE)+1
             if(JustCount) CYCLE

             NodeCount(i,j,k,nborBLK)=NodeCount(i,j,k,nborBLK)+1
             if(iPE==nborPE)then
                n=nRecv(iPE)
                VRecvIlocal(1,n)=i; VRecvIlocal(2,n)=j; VRecvIlocal(3,n)=k
                VRecvIlocal(4,n)=nborBLK
                VRecvIlocal(5,n)=NodeCount(i,j,k,nborBLK)
             else
                n=nRecvStart(iPE)+nRecv(iPE)
                VRecvI(1,n)=i; VRecvI(2,n)=j; VRecvI(3,n)=k
                VRecvI(4,n)=nborBLK
                VRecvI(5,n)=NodeCount(i,j,k,nborBLK)
             end if
          end do; end do; end do
       end if

    elseif(sSubF > 0)then !Send to finer level

       if(iProc == iPE)then
          do i=i1S,i2S; do j=j1S,j2S; do k=k1S,k2S
             nSend(nborPE)=nSend(nborPE)+1
             if(JustCount) CYCLE

             if(iPE==nborPE)then
                n=nSend(nborPE)
                VSendIlocal(0,n)=1
                VSendIlocal(1,n)=i; VSendIlocal(3,n)=j; VSendIlocal(5,n)=k
                VSendIlocal(2,n)=i; VSendIlocal(4,n)=j; VSendIlocal(6,n)=k
                VSendIlocal(7,n)=iBLK
             else
                n=nSendStart(nborPE)+nSend(nborPE)
                VSendI(0,n)=1
                VSendI(1,n)=i; VSendI(3,n)=j; VSendI(5,n)=k
                VSendI(2,n)=i; VSendI(4,n)=j; VSendI(6,n)=k
                VSendI(7,n)=iBLK
             end if
          end do; end do; end do
       end if
       if(iProc == nborPE)then
          do i=i1R,i2R,2; do j=j1R,j2R,2; do k=k1R,k2R,2
             nRecv(iPE)=nRecv(iPE)+1
             if(JustCount) CYCLE

             NodeCount(i,j,k,nborBLK)=NodeCount(i,j,k,nborBLK)+1
             if(iPE==nborPE)then
                n=nRecv(iPE)
                VRecvIlocal(1,n)=i; VRecvIlocal(2,n)=j; VRecvIlocal(3,n)=k
                VRecvIlocal(4,n)=nborBLK
                VRecvIlocal(5,n)=NodeCount(i,j,k,nborBLK)
             else
                n=nRecvStart(iPE)+nRecv(iPE)
                VRecvI(1,n)=i; VRecvI(2,n)=j; VRecvI(3,n)=k
                VRecvI(4,n)=nborBLK
                VRecvI(5,n)=NodeCount(i,j,k,nborBLK)
             end if
          end do; end do; end do
       end if

    elseif(sSubF == -1)then !Send to coarser level

       if(iProc == iPE)then
          do i=i1S,i2S,2; do j=j1S,j2S,2; do k=k1S,k2S,2
             nSend(nborPE)=nSend(nborPE)+1
             if(JustCount) CYCLE

             if(iPE==nborPE)then
                n=nSend(nborPE)
                VSendIlocal(0,n)=-idir
                VSendIlocal(1,n)=i   ; VSendIlocal(3,n)=j   ; VSendIlocal(5,n)=k
                VSendIlocal(2,n)=i   ; VSendIlocal(4,n)=j   ; VSendIlocal(6,n)=k
                VSendIlocal(7,n)=iBLK
             else
                n=nSendStart(nborPE)+nSend(nborPE)
                VSendI(0,n)=-idir
                VSendI(1,n)=i   ; VSendI(3,n)=j   ; VSendI(5,n)=k
                VSendI(2,n)=i+1 ; VSendI(4,n)=j+1 ; VSendI(6,n)=k+1
                VSendI(7,n)=iBLK
             end if
          end do; end do; end do
       end if
       if(iProc == nborPE)then
          do i=i1R,i2R; do j=j1R,j2R; do k=k1R,k2R
             nRecv(iPE)=nRecv(iPE)+1
             if(JustCount) CYCLE

             NodeCount(i,j,k,nborBLK)=NodeCount(i,j,k,nborBLK)+1
             if(iPE==nborPE)then
                n=nRecv(iPE)
                VRecvIlocal(1,n)=i; VRecvIlocal(2,n)=j; VRecvIlocal(3,n)=k
                VRecvIlocal(4,n)=nborBLK
                VRecvIlocal(5,n)=NodeCount(i,j,k,nborBLK)
             else
                n=nRecvStart(iPE)+nRecv(iPE)
                VRecvI(1,n)=i; VRecvI(2,n)=j; VRecvI(3,n)=k
                VRecvI(4,n)=nborBLK
                VRecvI(5,n)=NodeCount(i,j,k,nborBLK)
             end if
          end do; end do; end do
       end if

    end if

  end subroutine build_i

  !==========================================================================
  subroutine set_indices

    !-----------------------------------------
    !Set initial values
    i1S= 1 ; j1S= 1 ; k1S= 1;   i1R= 1 ; j1R= 1 ; k1R= 1
    i2S=-1 ; j2S=-1 ; k2S=-1;   i2R=-1 ; j2R=-1 ; k2R=-1

    if(sSubF==0)then
       !Set indices for neighbor block at same level

       !i
       select case(dLOOP(idir,1))
       case(1)
          i1S=1+nI ; i1R=1
          i2S=1+nI ; i2R=1
       case(-1)
          i1S=1    ; i1R=1+nI
          i2S=1    ; i2R=1+nI
       case(0)
          i1S=1    ; i1R=1
          i2S=1+nI ; i2R=1+nI
       end select

       !j
       select case(dLOOP(idir,2))
       case(1)
          j1S=1+nJ ; j1R=1
          j2S=1+nJ ; j2R=1
       case(-1)
          j1S=1    ; j1R=1+nJ
          j2S=1    ; j2R=1+nJ
       case(0)
          j1S=1    ; j1R=1
          j2S=1+nJ ; j2R=1+nJ
       end select

       !k
       select case(dLOOP(idir,3))
       case(1)
          k1S=1+nK ; k1R=1
          k2S=1+nK ; k2R=1
       case(-1)
          k1S=1    ; k1R=1+nK
          k2S=1    ; k2R=1+nK
       case(0)
          k1S=1    ; k1R=1
          k2S=1+nK ; k2R=1+nK
       end select

       RETURN
    end if

    if(sSubF>0)then
       !Set indices for finer neighbor block

       !i
       select case(dLOOP(idir,1))
       case(1)
          i1S=1+nI ; i1R=1
          i2S=1+nI ; i2R=1
       case(-1)
          i1S=1    ; i1R=1+nI
          i2S=1    ; i2R=1+nI
       case(0)
          select case(sSubF)
          case(1)
             i1S=1      ; i1R=1
             i2S=1+nI/2 ; i2R=1+nI
          case(2)
             select case(idir)
             case(3,4)
                i1S=1      ; i1R=1
                i2S=1+nI/2 ; i2R=1+nI
             case default
                i1S=1+nI/2 ; i1R=1
                i2S=1+nI   ; i2R=1+nI
             end select
          case(3)
             select case(idir)
             case(3,4)
                i1S=1+nI/2 ; i1R=1
                i2S=1+nI   ; i2R=1+nI
             case default
                i1S=1      ; i1R=1
                i2S=1+nI/2 ; i2R=1+nI
             end select
          case(4)
             i1S=1+nI/2    ; i1R=1
             i2S=1+nI      ; i2R=1+nI
          end select
       end select

       !j
       select case(dLOOP(idir,2))
       case(1)
          j1S=1+nJ ; j1R=1
          j2S=1+nJ ; j2R=1
       case(-1)
          j1S=1    ; j1R=1+nJ
          j2S=1    ; j2R=1+nJ
       case(0)
          select case(sSubF)
          case(1)
             j1S=1      ; j1R=1
             j2S=1+nJ/2 ; j2R=1+nJ
          case(2)
             select case(idir)
             case(1,2,3,4,5,6)
                j1S=1      ; j1R=1
                j2S=1+nJ/2 ; j2R=1+nJ
             case default
                j1S=1+nJ/2 ; j1R=1
                j2S=1+nJ   ; j2R=1+nJ
             end select
          case(3)
             j1S=1+nJ/2    ; j1R=1
             j2S=1+nJ      ; j2R=1+nJ
          case(4)
             j1S=1+nJ/2    ; j1R=1
             j2S=1+nJ      ; j2R=1+nJ
          end select
       end select

       !k
       select case(dLOOP(idir,3))
       case(1)
          k1S=1+nK ; k1R=1
          k2S=1+nK ; k2R=1
       case(-1)
          k1S=1    ; k1R=1+nK
          k2S=1    ; k2R=1+nK
       case(0)
          select case(sSubF)
          case(1)
             k1S=1      ; k1R=1
             k2S=1+nK/2 ; k2R=1+nK
          case(2)
             k1S=1+nK/2 ; k1R=1
             k2S=1+nK   ; k2R=1+nK
          case(3)
             k1S=1      ; k1R=1
             k2S=1+nK/2 ; k2R=1+nK
          case(4)
             k1S=1+nK/2 ; k1R=1
             k2S=1+nK   ; k2R=1+nK
          end select
       end select

       RETURN
    end if

    if(sSubF==-1)then
       !Set indices for coarser neighbor block

       !If rSubF=0, then the neighbor block is coarser, but shifted. No send needed.
       if(rSubF==0) RETURN

       !i
       select case(dLOOP(idir,1))
       case(1)
          i1S=1+nI ; i1R=1
          i2S=1+nI ; i2R=1
       case(-1)
          i1S=1    ; i1R=1+nI
          i2S=1    ; i2R=1+nI
       case(0)
          select case(rSubF)
          case(1)
             i1S=1    ; i1R=1
             i2S=1+nI ; i2R=1+nI/2
          case(2)
             select case(idir)
             case(3,4)
                i1S=1    ; i1R=1
                i2S=1+nI ; i2R=1+nI/2
             case default
                i1S=1    ; i1R=1+nI/2
                i2S=1+nI ; i2R=1+nI
             end select
          case(3)
             select case(idir)
             case(3,4)
                i1S=1    ; i1R=1+nI/2
                i2S=1+nI ; i2R=1+nI
             case default
                i1S=1    ; i1R=1
                i2S=1+nI ; i2R=1+nI/2
             end select
          case(4)
             i1S=1    ; i1R=1+nI/2
             i2S=1+nI ; i2R=1+nI
          end select
       end select

       !j
       select case(dLOOP(idir,2))
       case(1)
          j1S=1+nJ ; j1R=1
          j2S=1+nJ ; j2R=1
       case(-1)
          j1S=1    ; j1R=1+nJ
          j2S=1    ; j2R=1+nJ
       case(0)
          select case(rSubF)
          case(1)
             j1S=1    ; j1R=1
             j2S=1+nJ ; j2R=1+nJ/2
          case(2)
             select case(idir)
             case(1,2,3,4,5,6)
                j1S=1    ; j1R=1
                j2S=1+nJ ; j2R=1+nJ/2
             case default
                j1S=1    ; j1R=1+nJ/2
                j2S=1+nJ ; j2R=1+nJ
             end select
          case(3)
             j1S=1    ; j1R=1+nJ/2
             j2S=1+nJ ; j2R=1+nJ
          case(4)
             j1S=1    ; j1R=1+nJ/2
             j2S=1+nJ ; j2R=1+nJ
          end select
       end select

       !k
       select case(dLOOP(idir,3))
       case(1)
          k1S=1+nK ; k1R=1
          k2S=1+nK ; k2R=1
       case(-1)
          k1S=1    ; k1R=1+nK
          k2S=1    ; k2R=1+nK
       case(0)
          select case(rSubF)
          case(1)
             k1S=1    ; k1R=1
             k2S=1+nK ; k2R=1+nK/2
          case(2)
             k1S=1    ; k1R=1+nK/2
             k2S=1+nK ; k2R=1+nK
          case(3)
             k1S=1    ; k1R=1
             k2S=1+nK ; k2R=1+nK/2
          case(4)
             k1S=1    ; k1R=1+nK/2
             k2S=1+nK ; k2R=1+nK
          end select
       end select

       RETURN
    end if

  end subroutine set_indices

end subroutine mp_build_node_indices

!==========================================================================
!==========================================================================
!==========================================================================

!!$!------------------------------------------------------------------------------------!
!!$!
!!$!    North                      8--------------7
!!$!    y,j    Top               / |            / |
!!$!     ^     z,k             /   |          /   |
!!$!     |   /               /     |        /     |
!!$!     | /     West      5-------+------6       |
!!$!     |-----> x,i       |       |      |       |
!!$!                       |       1------+-------2
!!$!                       |     /        |     /
!!$!                       |   /          |   /
!!$!                       | /            | /
!!$!                       4--------------3 --(front, right, and bottom 3D box corner)
!!$!
!!$!  Point 7 is:  +x, +y, +z, West, North, Top
!!$!
!!$!  Point 4 is:  -x, -y, -z, East, South, Bottom
!!$!
!!$!------------------------------------------------------------------------------------!

!^CFG IF DEBUGGING BEGIN
!==========================================================================
!==========================================================================
!==========================================================================
subroutine testmessage_pass_nodes
  !
  ! This routine tests the new message passing for filling ghost node values
  !   It builds a desired result state in V0 made up of a linear combinations
  !   of X, Y, and Z.  Values are then put into V1(to V8), but only the inner
  !   computational nodes.  After message pass, V0 should equal V1(to V8).
  !
  use ModProcMH
  use ModMain, ONLY : unusedBLK
  use ModMPNodes
  use ModNodes
  use ModGeometry, ONLY : x_BLK, y_BLK, z_BLK
  use ModParallel, ONLY : BLKneighborLEV
  use ModMpi
  implicit none

  !Local variables
  integer :: i,j,k, n, iBLK, d1,d2,d3, i0,i1,i2, j0,j1,j2, k0,k1,k2, iError
  real, parameter :: f1=0.139191, f2=0.712727
  real, dimension(:,:,:,:), allocatable :: V0,V1

  !------------------------------------------

  write(*,*)' '
  write(*,*)'Testing message_pass_nodes, PE=',iProc,'  Starting tests ...'

  allocate( V0(1:nI+1,1:nJ+1,1:nK+1,nBLK), stat=iError ); call alloc_check(iError,"V0")
  allocate( V1(1:nI+1,1:nJ+1,1:nK+1,nBLK), stat=iError ); call alloc_check(iError,"V1")

  V0=-999999.
  V1=V0
  do iBLK=1,nBLK
     if(unusedBLK(iBLK)) CYCLE
     V0= NodeX_NB + f1*NodeY_NB + f2*NodeZ_NB
  end do
  V1=V0

  iNewGrid=iNewGrid+1

  call pass_and_average_nodes(.false.,V1)
  write(*,'(a,i3,a,i6,a,f5.1,a,a,i6,a,f5.1,a)')'MP SUMMARY, PE=',iProc, &
       ' numSend=',numSend+nSend(iProc), &
       ' (',100.*real(nSend(iProc))/real(numSend+nSend(iProc)),'% copies)', &
       ' numRecv=',numRecv+nRecv(iProc), &
       ' (',100.*real(nRecv(iProc))/real(numRecv+nRecv(iProc)),'% copies)'
!!$  do iPE=0,nProc-1
!!$     write(*,*)' PE=',iProc,' Send/Recv with PE=',iPE,' sending:',nSend(iPE),' receiving:',nRecv(iPE)
!!$  end do

  if(max(maxval(V1-V0),maxval(V0-V1))>.01)then
     write(*,*)'Testing message_pass_nodes, PE=',iProc,&
          ' max difference=', &
          max(maxval(V1-V0),maxval(V0-V1)), &
          ' printing out values and exiting.'
     write(*,*)' '
     do iBLK=1,nBLK
        if(unusedBLK(iBLK)) CYCLE
        n=0
        do i=1,nI+1; do j=1,nJ+1; do k=1,nK+1
           if(abs(V0(i,j,k,iBLK)-V1(i,j,k,iBLK))>.01) n=n+1
        end do; end do; end do
        if(n/=0) write(*,*)' PE=',iProc,' BLK=',iBLK,' has bad values ...'
        do i=1,nI+1; do j=1,nJ+1; do k=1,nK+1
           if(abs(V0(i,j,k,iBLK)-V1(i,j,k,iBLK))>.01)then
              write(*,*)' PE=',iProc,' BLK=',iBLK,' IJK=',i,j,k,&
                   ' Diff=',abs(V0(i,j,k,iBLK)-V1(i,j,k,iBLK)), &
                   ' Values=',V0(i,j,k,iBLK),V1(i,j,k,iBLK)
           end if
        end do; end do; end do
        if(n/=0) call stop_mpi('testmessage_pass_nodes n/=0')
     end do
     call stop_mpi("testmessage_pass_nodes error")
  end if

  deallocate(V0)
  deallocate(V1)

  write(*,*)'Testing message_pass_nodes, PE=',iProc,'  All tests passed.'
  write(*,*)' '

!!$  call MPI_BARRIER(iComm,iError) ! ----------- BARRIER ------
!!$  call MPI_Finalize(iError)
!!$  stop

end subroutine testmessage_pass_nodes
!^CFG END DEBUGGING

!==========================================================================
!==========================================================================
!==========================================================================
subroutine pass_and_average_nodes(DoFixHangingNodes,Vin)
  !
  ! This routine will message pass node values in variable Vin, result averaged.
  !
  use ModProcMH
  use ModOctree
  use ModMPNodes
  use ModMpi
  implicit none

  !Subroutine arguements
  logical, intent(in) :: DoFixHangingNodes
  real, intent(inout), dimension(1:nI+1,1:nJ+1,1:nK+1,nBLK) :: Vin

  !Local variables
  integer :: i,j,k, iBLK,iPE

  !------------------------------------------

  ! Assign value to internal passing variable and do message pass
  V(:,:,:,:,1) = Vin(:,:,:,:)
  call message_pass_nodes

  ! Average values passed and put back into Vin
  do iBLK=1,nBLK
     if (.not.associated(global_block_ptrs(iBLK, iProc+1) % ptr)) CYCLE
     if (.not.global_block_ptrs(iBLK, iProc+1) % ptr % used) CYCLE
     do i=1,nI+1; do j=1,nJ+1; do k=1,nK+1
        if(NodeCount(i,j,k,iBLK)>1) &
             Vin(i,j,k,iBLK) = sum(V(i,j,k,iBLK,1:NodeCount(i,j,k,iBLK)))/real(NodeCount(i,j,k,iBLK))
     end do; end do; end do
  end do

  ! If we are fixing hanging nodes, call routine
  if(DoFixHangingNodes) call set_block_hanging_nodes(Vin)

end subroutine pass_and_average_nodes

!==========================================================================
!==========================================================================
!==========================================================================
subroutine pass_and_max_nodes(DoFixHangingNodes,Vin)
  !
  ! This routine will message pass node values in variable Vin, result maxed.
  !
  use ModProcMH
  use ModOctree
  use ModMPNodes
  use ModMpi
  implicit none

  !Subroutine arguements
  logical, intent(in) :: DoFixHangingNodes
  real, intent(inout), dimension(1:nI+1,1:nJ+1,1:nK+1,nBLK) :: Vin

  !Local variables
  integer :: i,j,k, iBLK

  !------------------------------------------

  ! Assign value to internal passing variable and do message pass
  V(:,:,:,:,1) = Vin(:,:,:,:)
  call message_pass_nodes

  ! Max values passed and put back into Vin
  do iBLK=1,nBLK
     if (.not.associated(global_block_ptrs(iBLK, iProc+1) % ptr)) CYCLE
     if (.not.global_block_ptrs(iBLK, iProc+1) % ptr % used) CYCLE
     do i=1,nI+1; do j=1,nJ+1; do k=1,nK+1
        if(NodeCount(i,j,k,iBLK)>1) &
             Vin(i,j,k,iBLK) = maxval(V(i,j,k,iBLK,1:NodeCount(i,j,k,iBLK)))
     end do; end do; end do
  end do

  ! If we are fixing hanging nodes, call routine
  if(DoFixHangingNodes) call set_block_hanging_nodes(Vin)

end subroutine pass_and_max_nodes

!==========================================================================
!==========================================================================
!==========================================================================
subroutine set_block_hanging_nodes(Vin)
  !
  ! This routine will fix hanging nodes by simple interpolation.
  !
  use ModProcMH
  use ModMain, ONLY : nI,nJ,nK,nBLK
  use ModOctree
  implicit none

  !Subroutine arguements
  real, intent(inout), dimension(1:1+nI,1:1+nJ,1:1+nK,nBLK) :: Vin

  !Local variables
  integer :: i,j,k, iBLK,iPE
  integer :: i1,i2, j1,j2, k1,k2, iOffset,jOffset,kOffset
  integer :: neighborLEV, idir
  integer, dimension(26,3) :: dLOOP
  integer, dimension(4) :: neighborPE,neighborBLK,neighborCHILD

  !------------------------------------------

  ! face=1-6, edge=7-18, corner=19-26
  !    1   2   3   4   5   6    7   8   9  10  11  12  13  14  15  16  17  18   19  20  21  22  23  24  25  26
  !    W   E   N   S   T   B   WN  ES  WS  EN  NT  SB  NB  ST  TW  BE  TE  BW  WNT ESB WNB EST WST ENB WSB ENT
  data dLOOP / &
       1, -1,  0,  0,  0,  0,   1, -1,  1, -1,  0,  0,  0,  0,  1, -1, -1,  1,   1, -1,  1, -1,  1, -1,  1, -1, &
       0,  0,  1, -1,  0,  0,   1, -1, -1,  1,  1, -1,  1, -1,  0,  0,  0,  0,   1, -1,  1, -1, -1,  1, -1,  1, &
       0,  0,  0,  0,  1, -1,   0,  0,  0,  0,  1, -1, -1,  1,  1, -1,  1, -1,   1, -1, -1,  1,  1, -1, -1,  1 /

  ! Fix hanging nodes
  iPE=iProc
  do iBLK=1,nBLK
     if (.not.associated(global_block_ptrs(iBLK, iProc+1) % ptr)) CYCLE
     if (.not.global_block_ptrs(iBLK, iProc+1) % ptr % used) CYCLE

     ! Just loop over faces and edges, not corners
     do idir=1,18
        call treeNeighbor(iPE,iBLK,dLOOP(idir,1),dLOOP(idir,2),dLOOP(idir,3), &
             neighborPE,neighborBLK,neighborCHILD,neighborLEV)

        ! If coarser neighbor, fix hanging nodes
        if(neighborLEV==1)then

           select case(dLOOP(idir,1))
           case( 1)
              i1=1+nI; i2=1+nI; iOffset=0
           case(-1)
              i1=1;    i2=1;    iOffset=0
           case( 0)
              i1=2;    i2=nI;   iOffset=1
           end select

           select case(dLOOP(idir,2))
           case( 1)
              j1=1+nJ; j2=1+nJ; jOffset=0
           case(-1)
              j1=1;    j2=1;    jOffset=0
           case( 0)
              j1=2;    j2=nJ;   jOffset=1
           end select

           select case(dLOOP(idir,3))
           case( 1)
              k1=1+nK; k2=1+nK; kOffset=0
           case(-1)
              k1=1;    k2=1;    kOffset=0
           case( 0)
              k1=2;    k2=nK;   kOffset=1
           end select

           ! Correct edge nodes and some interior face nodes
           do i=i1,i2,2; do j=j1,j2,2; do k=k1,k2,2
              Vin(i,j,k,iBLK) = 0.125 * ( &
                   Vin(i-iOffset,j-jOffset,k-kOffset,iBLK) + &
                   Vin(i-iOffset,j-jOffset,k+kOffset,iBLK) + &
                   Vin(i-iOffset,j+jOffset,k-kOffset,iBLK) + &
                   Vin(i-iOffset,j+jOffset,k+kOffset,iBLK) + &
                   Vin(i+iOffset,j-jOffset,k-kOffset,iBLK) + &
                   Vin(i+iOffset,j-jOffset,k+kOffset,iBLK) + &
                   Vin(i+iOffset,j+jOffset,k-kOffset,iBLK) + &
                   Vin(i+iOffset,j+jOffset,k+kOffset,iBLK) )
           end do; end do; end do

           ! Add correction of additional interior face nodes
           if(idir<=6)then
              if(iOffset==1)then
                 do i=i1-1,i2+1,2; do j=j1,j2,2; do k=k1,k2,2
                    Vin(i,j,k,iBLK) = 0.25 * ( &
                         Vin(i,j-jOffset,k-kOffset,iBLK) + &
                         Vin(i,j-jOffset,k+kOffset,iBLK) + &
                         Vin(i,j+jOffset,k-kOffset,iBLK) + &
                         Vin(i,j+jOffset,k+kOffset,iBLK) )
                 end do; end do; end do
              end if
              if(jOffset==1)then
                 do i=i1,i2,2; do j=j1-1,j2+1,2; do k=k1,k2,2
                    Vin(i,j,k,iBLK) = 0.25 * ( &
                         Vin(i-iOffset,j,k-kOffset,iBLK) + &
                         Vin(i-iOffset,j,k+kOffset,iBLK) + &
                         Vin(i+iOffset,j,k-kOffset,iBLK) + &
                         Vin(i+iOffset,j,k+kOffset,iBLK) )
                 end do; end do; end do
              end if
              if(kOffset==1)then
                 do i=i1,i2,2; do j=j1,j2,2; do k=k1-1,k2+1,2
                    Vin(i,j,k,iBLK) = 0.25 * ( &
                         Vin(i-iOffset,j-jOffset,k,iBLK) + &
                         Vin(i-iOffset,j+jOffset,k,iBLK) + &
                         Vin(i+iOffset,j-jOffset,k,iBLK) + &
                         Vin(i+iOffset,j+jOffset,k,iBLK) )
                 end do; end do; end do
              end if
           end if

        end if
     end do
  end do

end subroutine set_block_hanging_nodes

!==========================================================================
!==========================================================================
!==========================================================================
subroutine assign_node_numbers
  use ModProcMH
  use ModIO, ONLY: write_prefix, iUnitOut
  use ModMain, ONLY : lVerbose, nBlock, nBlockMax, nBlockALL
  use ModOctree
  use ModAdvance,  ONLY: iTypeAdvance_B, iTypeAdvance_BP, SkippedBlock_
  use ModNodes
  use ModMPNodes
  use ModMpi
  implicit none

  integer, parameter :: NodesPerBlock=(nI+1)*(nJ+1)*(nK+1)
  integer :: iBlockStart
  integer :: i, j, k, iNode, iBLK, iError
  integer :: nOffset, nOffsetPrevious
  integer, allocatable, dimension(:) :: NodeOffset, NodeOffsetMax, nOffset_P

  !------------------------------------------

  ! Write information to the screen
  if(iProc==0.and.lVerbose>0)then
     call write_prefix; write(iUnitOut,*)'Starting assign_node_numbers ...'
  end if

  ! Initialize all node numbers to zero
  NodeNumberLocal_NB=0

  ! Number of nodes on each block (maximum)
  nNodeALL=nBlockALL*NodesPerBlock

  ! Count number of used blocks on all processors with rank less than this one
  iBlockStart = 0
  if(iProc > 0) iBlockStart = &
       count(iTypeAdvance_BP(1:nBlockMax,0:iProc-1) /= SkippedBlock_)

  iNode = iBlockStart*NodesPerBlock

  ! Loop to assign local and global node numbers
  TREE1: do iBlk  = 1, nBlock
     if(iTypeAdvance_B(iBlk) == SkippedBlock_) CYCLE
     do k=1,nK+1; do j=1,nJ+1; do i=1,nI+1
        iNode = iNode+1
        NodeNumberLocal_NB(i,j,k,iBlk)= iNode
     end do; end do; end do
  end do TREE1
  NodeNumberGlobal_NB = NodeNumberLocal_NB

  ! Set logical array
  NodeUniqueGlobal_NB = NodeNumberGlobal_NB>0

  ! Assign value to internal passing variable and do message pass
  !  NOTE: convert integer to real for message pass first
  V(:,:,:,:,1) = real(NodeNumberGlobal_NB(:,:,:,:))
  call message_pass_nodes

  ! Put minimum value back into NodeNumberGlobal_NB
  !  NOTE: convert message passed real back to integer
  do iBLK=1,nBLK
     if (.not.associated(global_block_ptrs(iBLK, iProc+1) % ptr)) CYCLE
     if (.not.global_block_ptrs(iBLK, iProc+1) % ptr % used) CYCLE
     do k=1,nK+1; do j=1,nJ+1; do i=1,nI+1
        if(NodeCount(i,j,k,iBLK)>1) &
             NodeNumberGlobal_NB(i,j,k,iBLK) = &
             nint(minval(V(i,j,k,iBLK,1:NodeCount(i,j,k,iBLK))))
     end do; end do; end do
  end do

  !Allocate memory for storing the node offsets
  allocate( NodeOffset   (nBlockALL*NodesPerBlock), stat=iError)
  call alloc_check(iError,"NodeOffset")
  allocate( NodeOffsetMax(nBlockALL*NodesPerBlock), stat=iError)
  call alloc_check(iError,"NodeOffsetMax")
  NodeOffset=0

  ! Loop to compute node offsets
  nOffset=0
  TREE2: do iBLK  = 1, nBlock
     if(iTypeAdvance_B(iBLK) == SkippedBlock_) CYCLE
     do k=1,nK+1; do j=1,nJ+1; do i=1,nI+1
        if(NodeNumberLocal_NB(i,j,k,iBLK) &
             > NodeNumberGlobal_NB(i,j,k,iBLK))then
           nOffset = nOffset+1
           NodeUniqueGlobal_NB(i,j,k,iBLK) = .false.
        end if
        NodeOffset(NodeNumberLocal_NB(i,j,k,iBLK)) = nOffset
     end do; end do; end do
  end do TREE2

  ! Collect offsets from all the PEs
  allocate(nOffset_P(0:nProc-1))
  call MPI_allgather(nOffset, 1, MPI_INTEGER, nOffset_P, 1, MPI_INTEGER, &
       iComm, iError)

  ! Add up the offsets on processors with lower rank
  nOffsetPrevious = 0
  if(iProc > 0) nOffsetPrevious = sum(nOffset_P(0:iProc-1))

  ! Increase the offset on this processor by nOffsetPrevious
  do iBLK  = 1, nBlock
     if(iTypeAdvance_B(iBLK) == SkippedBlock_) CYCLE
     do k=1,nK+1; do j=1,nJ+1; do i=1,nI+1
        iNode = NodeNumberLocal_NB(i,j,k,iBLK)
        NodeOffset(iNode) = NodeOffset(iNode) + nOffsetPrevious
     end do; end do; end do
  end do

  ! Gather offsets from all PE-s. NodeOffset is initialized to 0.
  call MPI_allreduce(NodeOffset,NodeOffsetMax,nBlockALL*NodesPerBlock, &
       MPI_INTEGER,MPI_MAX,iComm,iError)
  NodeOffset = NodeOffsetMax
  nNodeALL   = nNodeALL - sum(nOffset_P)

  ! Loop to fix NodeNumberGlobal_NB for offset
  TREE3: do iBlk  = 1, nBlock
     if(iTypeAdvance_B(iBLK) == SkippedBlock_) CYCLE
     do k=1,nK+1; do j=1,nJ+1; do i=1,nI+1
        NodeNumberGlobal_NB(i,j,k,iBLK) = NodeNumberGlobal_NB(i,j,k,iBLK) &
             - NodeOffset(NodeNumberGlobal_NB(i,j,k,iBLK))
        if(NodeNumberGlobal_NB(i,j,k,iBLK)>nNodeALL &
             .or. NodeNumberGlobal_NB(i,j,k,iBLK)<1)then
           ! Error in numbering, report values and stop.
           write(*,*)'ERROR: Global node numbering problem.', &
                ' PE=',iProc,' BLK=',iBLK,' ijk=',i,j,k
           write(*,*)'  NodeNumberGlobal_NB=',&
                NodeNumberGlobal_NB(i,j,k,iBLK)
           write(*,*)'  NodeOffset           =',&
                NodeOffset(NodeNumberGlobal_NB(i,j,k,iBLK))
           write(*,*)'  nBlockALL=',nBlockALL,&
                ' NodesPerBlock=',NodesPerBlock,&
                ' unreduced total=',nBlockALL*NodesPerBlock,&
                ' nNodeALL=',nNodeALL
           call stop_mpi('message_pass_nodes: error in numbering')
        end if
     end do; end do; end do
  end do TREE3

  ! Deallocate memory when done with it
  deallocate(NodeOffset, NodeOffsetMax, nOffset_P)

  ! Write information to the screen
  if(iProc==0)then
     call write_prefix; write(iUnitOUt,*) &
          ' nBlockALL=',nBlockALL,' NodesPerBlock=',NodesPerBlock, &
          ' unreduced total=',nBlockALL*NodesPerBlock,' nNodeALL=',nNodeALL
  end if

!!$  ! Test
!!$  call testmessage_pass_nodes

end subroutine assign_node_numbers
