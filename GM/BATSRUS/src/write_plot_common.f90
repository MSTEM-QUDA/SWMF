!^CFG COPYRIGHT UM
!=============================================================================
subroutine write_plot_common(ifile)

  ! routine that loops over all blocks per processor and write the appropriate
  ! output files.

  use ModProcMH
  use ModMain
  use ModGeometry, ONLY : XyzMin_D,XyzMax_D,true_cell
  use ModGeometry, ONLY : TypeGeometry,UseCovariant     
  use ModPhysics, ONLY : No2Io_V, UnitX_, thetaTilt,Rbody
  use ModIO
  use ModIoUnit, ONLY : io_unit_new
  use ModNodes
  use ModNumConst, ONLY : cPi
  use ModMpi
  implicit none


  ! Arguments

  integer, intent(in) :: ifile

  ! Local variables

  integer :: iError

  ! Plot variables
  real :: PlotVar(-1:nI+2,-1:nJ+2,-1:nK+2,nplotvarmax)
  real :: PlotVarBlk(-1:nI+2,-1:nJ+2,-1:nK+2,nplotvarmax)
  real :: PlotVar_inBody(nplotvarmax)
  logical :: PlotVar_useBody(nplotvarmax)
  real, allocatable :: PlotVarNodes_NBI(:,:,:,:,:)

  character (len=10) :: plotvarnames(nplotvarmax)
  integer :: nplotvar

  ! Equation parameters
  integer, parameter :: neqparmax=10
  real :: eqpar(neqparmax)
  character (len=10) :: eqparnames(neqparmax)
  integer :: neqpar

  character (LEN=500) :: allnames
  character (LEN=500) :: unitstr_TEC, unitstr_IDL
  character (LEN=4) :: file_extension
  character (LEN=500) :: file_format
  character (len=80) :: filename_n, filename_s
  character (len=1) :: NorthOrSouth

  ! Indices and coordinates
  integer :: iBLK,i,j,k,iVar
  integer :: ntheta, nphi
  real :: xmin,xmax,ymin,ymax,zmin,zmax
  real :: rplot
  real :: dxblk,dyblk,dzblk,dxblk_out

  real :: dxPEmin(3),dxGLOBALmin(3)
  integer :: nPEcells, nBLKcells, nGLOBALcells
  integer :: nPEcellsN,nPEcellsS,nBLKcellsN, nBLKcellsS
  integer :: nGLOBALcellsN,nGLOBALcellsS

  integer :: iTime_I(7)

  logical :: oktest,oktest_me
  !---------------------------------------------------------------------------

  ! Initialize stuff
  call set_oktest('write_plot_common',oktest,oktest_me)

  PlotVar = 0.0
  plotvar_inBody = 0.0
  plotvar_useBody = .false.

  unitstr_TEC = ''
  unitstr_IDL = ''

  plot_type1=plot_type(ifile)
  plot_vars1=plot_vars(ifile)
  plot_pars1=plot_pars(ifile)

  if(oktest_me)write(*,*)'ifile=',ifile,' plot_type=',plot_type1, &
       ' form = ',plot_form(ifile)

  call split_str(plot_vars1,nplotvarmax,plotvarnames,nplotvar)
  call split_str(plot_pars1,neqparmax,eqparnames,neqpar)
  call set_eqpar(ifile-plot_,neqpar,eqparnames,eqpar)

  allnames=trim(plot_vars1)//' '//plot_pars1

  if(oktest_me) then
     write(*,*) plot_vars1
     write(*,*) nplotvar,plotvarnames
     write(*,*) plot_dx(:,ifile)
     write(*,*) plot_range(:,ifile)
     write(*,*) plot_type1
     write(*,*) plot_form(ifile)
  end if

  ! Construct the file name
  if (ifile-plot_ > 9) then
     file_format='("' // trim(NamePlotDir) // '",a,i2,a,i7.7,a,i4.4,a)'
  else
     file_format='("' // trim(NamePlotDir) // '",a,i1,a,i7.7,a,i4.4,a)'
  end if

  ! For time accurate runs the file name will contain the StringDateOrTime
  if(time_accurate)call get_time_string

  select case(plot_form(ifile))
  case('tec')
     file_extension='.tec'
  case('idl')
     file_extension='.idl'
  end select
  if(index(plot_type1,'sph')>0)then
     if(time_accurate)then
        ! do the northern hemisphere
        write(filename_n,file_format) &
             plot_type1(1:2)//"N"//plot_type1(4:len_trim(plot_type1))//"_",&
             ifile-plot_,"_t"//StringDateOrTime//"_n",n_step,"_pe",iProc,&
             file_extension
        ! do the southern hemisphere
        write(filename_s,file_format) &
             plot_type1(1:2)//"S"//plot_type1(4:len_trim(plot_type1))//"_",&
             ifile-plot_,"_t"//StringDateOrTime//"_n",n_step,"_pe",iProc,&
             file_extension
     else
        ! do the northern hemisphere
        write(filename_n,file_format) &
             plot_type1(1:2)//"N"//plot_type1(4:len_trim(plot_type1))//"_",&
             ifile-plot_,"_n",n_step,"_pe",iProc,file_extension
        ! do the southern hemisphere
        write(filename_s,file_format) &
             plot_type1(1:2)//"S"//plot_type1(4:len_trim(plot_type1))//"_",&
             ifile-plot_,"_n",n_step,"_pe",iProc,file_extension
     end if
     ! open the files
     unit_tmp2 = io_unit_new()
     if(save_binary .and. plot_form(ifile)=='idl') then
        open(unit_tmp ,file=filename_n,status="replace",err=999,&
             form="unformatted")
        open(unit_tmp2,file=filename_s,status="replace",err=999,&
             form="unformatted")
     else
        open(unit_tmp ,file=filename_n,status="replace",err=999)
        open(unit_tmp2,file=filename_s,status="replace",err=999)
     end if
  elseif(plot_form(ifile)=='tec')then
     if(time_accurate)then
        write(filename_n,file_format) &
             trim(plot_type1)//"_",&
             ifile-plot_,"_t"//StringDateOrTime//"_n",n_step,"_1_pe",iProc,&
             file_extension
        write(filename_s,file_format) &
             trim(plot_type1)//"_",&
             ifile-plot_,"_t"//StringDateOrTime//"_n",n_step,"_2_pe",iProc,&
             file_extension
     else
        write(filename_n,file_format) &
             trim(plot_type1)//"_",&
             ifile-plot_,"_n",n_step,"_1_pe",iProc,file_extension
        write(filename_s,file_format) &
             trim(plot_type1)//"_",&
             ifile-plot_,"_n",n_step,"_2_pe",iProc,file_extension
     end if
     unit_tmp2 = io_unit_new()
     ! Open files
     open(unit_tmp ,file=filename_n,status="replace",err=999)
     open(unit_tmp2,file=filename_s,status="replace",err=999)
  else
     if(time_accurate)then
        write(filename,file_format) &
             trim(plot_type1)//"_",&
             ifile-plot_,"_t"//StringDateOrTime//"_n",n_step,"_pe",iProc,&
             file_extension
     else
        write(filename,file_format) &
             trim(plot_type1)//"_",&
             ifile-plot_,"_n",n_step,"_pe",iProc,file_extension
     end if
     ! Open file
     if(save_binary .and. plot_form(ifile)=='idl')then
        open(unit_tmp,file=filename,status="replace",err=999,&
             form="unformatted")
     else
        open(unit_tmp,file=filename,status="replace",err=999)
     end if
  end if

  if (index(plot_type1,'sph')>0) then
     ntheta = 1 + 180.0/plot_dx(2,ifile)
     nphi   = 360.0/plot_dx(3,ifile)
     rplot  = plot_range(1,ifile)
     if(oktest_me) then
        write(*,*) ntheta,nphi
     end if
  end if

  !! START IDL
  ! define from values used in the plotting, so that they don't
  ! have to be done inside the loop
  xmin=plot_range(1,ifile)
  xmax=plot_range(2,ifile)
  ymin=plot_range(3,ifile)
  ymax=plot_range(4,ifile)
  zmin=plot_range(5,ifile)
  zmax=plot_range(6,ifile)

  dxPEmin(:)=XyzMax_D(:)-XyzMin_D(:)

  dxblk=XyzMax_D(1)-XyzMin_D(1)
  dyblk=XyzMax_D(2)-XyzMin_D(2)
  dzblk=XyzMax_D(3)-XyzMin_D(3)
  nPEcells=0; nPEcellsN=0; nPEcellsS=0
  nBLKcells=0; nBLKcellsN=0; nBLKcellsS=0
  !! END IDL

  ! Compute the plot variables and write them to the disk
  PlotVarBlk=0.
  do iBLK=1,nBlockMax
     if(unusedBLK(iBLK))CYCLE

     call set_plotvar(iBLK, &
          ifile-plot_,nplotvar,plotvarnames,plotvar,plotvar_inBody,plotvar_useBody)
     if (plot_dimensional(ifile)) call dimensionalize_plotvar(iBLK, &
          ifile-plot_,nplotvar,plotvarnames,plotvar,plotvar_inBody)

     if (index(plot_type1,'sph')>0) then
        call write_plot_sph(ifile,iBLK,nplotvar,plotvar, &
             ntheta,nphi,rplot,nBLKcellsN,nBLKcellsS)
   	dxblk=1.0
   	dyblk=180.0/real(ntheta-1)
   	dzblk=360.0/real(nphi)
     else
        select case(plot_form(ifile))
        case('tec')
           call plotvar_to_plotvarnodes
           if ( plot_point(1,ifile)> NodeX_NB(1   ,1   ,1   ,iBLK) .and. &
                plot_point(1,ifile)<=NodeX_NB(1+nI,1+nJ,1+nK,iBLK) .and. &
                plot_point(2,ifile)> NodeY_NB(1   ,1   ,1   ,iBLK) .and. &
                plot_point(2,ifile)<=NodeY_NB(1+nI,1+nJ,1+nK,iBLK) .and. &
                plot_point(3,ifile)> NodeZ_NB(1   ,1   ,1   ,iBLK) .and. &
                plot_point(3,ifile)<=NodeZ_NB(1+nI,1+nJ,1+nK,iBLK) )then
              PlotVarBlk=PlotVar
           end if
        case('idl')
           call write_plot_idl(ifile,iBLK,nplotvar,plotvar, &
                xmin,xmax,ymin,ymax,zmin,zmax, &
                dxblk,dyblk,dzblk,nBLKcells)
        end select
     end if

     if (plot_form(ifile)=='idl') then
   	! Update number of cells per processor
        if (.not. (index(plot_type1,'sph')>0)) then
      	   nPEcells = nPEcells + nBLKcells
        else
      	   nPEcellsN = nPEcellsN + nBLKcellsN
      	   nPEcellsS = nPEcellsS + nBLKcellsS
        end if

   	! Find smallest cell size in the plotting region
   	dxPEmin(1)=min(dxPEmin(1),dxblk)
   	dxPEmin(2)=min(dxPEmin(2),dyblk)
   	dxPEmin(3)=min(dxPEmin(3),dzblk)
     end if

  end do ! iBLK

  ! Get the headers that contain variables names and units
  select case(plot_form(ifile))
  case('tec')
     call get_tec_variables(ifile,nplotvar,plotvarnames,unitstr_TEC)
     if(oktest .and. iProc==0) write(*,*)unitstr_TEC
  case('idl')
     call get_idl_units(ifile,nplotvar,plotvarnames,unitstr_IDL)
     if(oktest .and. iProc==0) write(*,*)unitstr_IDL
  end select

  ! Write files for new tecplot format
  if(plot_form(ifile)=='tec' .and. .NOT.(index(plot_type1,'sph')>0) )then
     do i=1,nplotvar
        NodeValue_NB=PlotVarNodes_NBI(:,:,:,:,i)
        call pass_and_average_nodes(.true.,NodeValue_NB)
        PlotVarNodes_NBI(:,:,:,:,i)=NodeValue_NB
     end do
     call write_plot_tec(ifile,nPlotVar,PlotVarBlk,PlotVarNodes_NBI,unitstr_TEC, &
          xmin,xmax,ymin,ymax,zmin,zmax)
     deallocate(PlotVarNodes_NBI)
  end if

  close(unit_tmp)
  if( (index(plot_type1,'sph')>0) .or. plot_form(ifile)=='tec' )then
     close(unit_tmp2)
  end if

  !! START IDL
  if (plot_form(ifile)=='idl')then
     ! Find smallest cell size and total number of cells
     if (.not. (index(plot_type1,'sph')>0)) then
        call MPI_reduce(dxPEmin,dxGLOBALmin,3,MPI_REAL,MPI_MIN,0,iComm,iError)
        call MPI_reduce(nPEcells,nGLOBALcells,1,MPI_INTEGER,MPI_SUM,0,iComm,iError)
     else
        call MPI_reduce(nPEcellsN,nGLOBALcellsN,1,MPI_INTEGER,MPI_SUM,0,iComm,iError)
        call MPI_reduce(nPEcellsS,nGLOBALcellsS,1,MPI_INTEGER,MPI_SUM,0,iComm,iError)
        dxGLOBALmin = dxPEmin
     end if

     if(oktest_me) then
        if (.not. (index(plot_type1,'sph')>0)) then
           write(*,*)'dxPEmin,nPEcells=',dxPEmin,nPEcells
        else
           write(*,*)'North: nGLOBALcells=',nGLOBALcellsN
           write(*,*)'South: nGLOBALcells=',nGLOBALcellsS
        end if
     end if
  end if
  !! END IDL

  ! write header file
  if(iProc==0)then

     select case(plot_form(ifile))
     case('tec')
        if (index(plot_type1,'sph')>0) then
           file_extension='.S'
        else  
           file_extension='.T'
        end if
     case('idl')
        file_extension='.h'
     end select

     if (ifile-plot_ > 9) then
        file_format='("' // trim(NamePlotDir) // '",a,i2,a,i7.7,a)'
     else
        file_format='("' // trim(NamePlotDir) // '",a,i1,a,i7.7,a)'
     end if

     do i=1,2
        
        !For spherical plots there is a north and south files
        !For other cases, cycle when i=2.  This saves a lot of 
        !double coding.
        if (.not.(index(plot_type1,'sph')>0) .and. i==2) CYCLE

        if(index(plot_type1,'sph')>0)then
           if (i==1) then
              NorthOrSouth='N'   ! do the northern hemisphere
              nGLOBALcells = nGLOBALcellsN
           else
              NorthOrSouth='S'   ! do the southern hemisphere
              nGLOBALcells = nGLOBALcellsS
           end if
           if(time_accurate) then
              write(filename,file_format) &
                   plot_type1(1:2)//NorthOrSouth// &
                   plot_type1(4:len_trim(plot_type1))//"_",&
                   ifile-plot_,"_t"//StringDateOrTime//"_n",&
                   n_step,file_extension
           else
              write(filename,file_format) &
                   plot_type1(1:2)//NorthOrSouth// &
                   plot_type1(4:len_trim(plot_type1))//"_",&
                   ifile-plot_,"_n",n_step,file_extension
           end if
        elseif(plot_form(ifile)=='tec')then
           if(time_accurate)then
              call get_time_string
              write(filename,file_format) &
                   trim(plot_type1)//"_",&
                   ifile-plot_,"_t"//StringDateOrTime//"_n",&
                   n_step,file_extension
           else
              write(filename,file_format) &
                   trim(plot_type1)//"_",&
                   ifile-plot_,"_n",n_step,file_extension
           end if
        else
           if(time_accurate)then
              call get_time_string
              write(filename,file_format) &
                   trim(plot_type1)//"_",&
                   ifile-plot_,"_t"//StringDateOrTime//"_n",&
                   n_step,file_extension
           else
              write(filename,file_format) &
                   trim(plot_type1)//"_",&
                   ifile-plot_,"_n",n_step,file_extension
           end if
        end if
        open(unit_tmp,file=filename,status="replace",err=999)

        write(unit_tmp,'(a)')filename
        write(unit_tmp,'(i8,a)')nProc,' nProc'
        write(unit_tmp,'(i8,a)')n_step,' n_step'
        write(unit_tmp,'(1pe13.5,a)')time_simulation,' t'
        select case(plot_form(ifile))
        case('tec')
           write(unit_tmp,'(a)')trim(unitstr_TEC)
           if(index(plot_type1,'sph')>0)  &
                write(unit_tmp,'(2(1pe13.5),a)') plot_dx(2:3,ifile),' plot_dx'
           call get_date_time(iTime_I)
           write(unit_tmp,*) iTime_I(1:7),' year mo dy hr mn sc msc'        
           write(unit_tmp,'(2(1pe13.5),a)') thetaTilt*180.0/cPi, 0.0,  &
                                            ' thetatilt[deg] phitilt[deg]'
           if (index(plot_type1,'sph')>0) then
              write(unit_tmp,'(es13.5,a)')rplot,' rplot'
              if (i==1) write(unit_tmp,'(a)')'Northern Hemisphere'
              if (i==2) write(unit_tmp,'(a)')'Southern Hemisphere'
           end if
        case('idl')
           if(plot_dimensional(ifile)) then
              write(unit_tmp,'(6(1pe18.10),a)') &
                   plot_range(:,ifile)*No2Io_V(UnitX_),' plot_range'
              write(unit_tmp,'(6(1pe18.10),i8,a)') &
                   plot_dx(:,ifile)*No2Io_V(UnitX_), &
                   dxGLOBALmin*No2Io_V(UnitX_), nGLOBALcells,&
                   ' plot_dx, dxmin, ncell'
           else
              write(unit_tmp,'(6(1pe18.10),a)') &
                   plot_range(:,ifile),' plot_range'
              write(unit_tmp,'(6(1pe18.10),i8,a)') &
                   plot_dx(:,ifile), dxGLOBALmin, nGLOBALcells,&
                   ' plot_dx, dxmin, ncell'
           end if
           write(unit_tmp,'(i8,a)')nplotvar  ,' nplotvar'
           write(unit_tmp,'(i8,a)')neqpar,' neqpar'
           write(unit_tmp,'(10(1pe13.5))')eqpar(1:neqpar)
           write(unit_tmp,'(a)')trim(allnames)
           write(unit_tmp,'(a)')trim(unitstr_IDL)
           write(unit_tmp,'(l8,a)')save_binary,' save_binary'
           if(save_binary)write(unit_tmp,'(i8,a)')nByteReal,' nByteReal'
           write(unit_tmp,'(a)')TypeGeometry
        end select
        close(unit_tmp)
     end do
  end if


  if(oktest_me)write(*,*)'write_plot_common finished'

  return

999 continue

  call stop_mpi("Error in opening or writing file in write_plot_common")

contains

  subroutine plotvar_to_plotvarnodes
    integer :: ii,jj,kk
    integer, dimension(0:nI+2, 0:nJ+2, 0:nK+2, nplotvarmax) :: nodeCount
    real,    dimension(0:nI+2, 0:nJ+2, 0:nK+2, nplotvarmax) :: nodeV
    real :: rr

    if(.not.allocated(PlotVarNodes_NBI)) allocate(&
         PlotVarNodes_NBI(1:1+nI,1:1+nJ,1:1+nK,nBLK,nplotvarmax),stat=iError)
    call alloc_check(iError,'write_plot_common:PlotVarNodes_NBI')

    ! Initialize values
    nodeCount = 0; nodeV = 0.00

    ! Cell loop now skips ghost cells.  message_pass_nodes does average.
    do k=1,nK; do j=1,nJ; do i=1,nI  ! Cell loop
       do iVar=1,nplotvar
          if ( true_cell(i,j,k,iBLK) .or. plotvar_useBody(iVar) )then
             do kk=0,1; do jj=0,1; do ii=0,1
                nodeCount(i+ii,j+jj,k+kk,iVar) = nodeCount(i+ii,j+jj,k+kk,iVar) +1
                nodeV(i+ii,j+jj,k+kk,iVar) = nodeV(i+ii,j+jj,k+kk,iVar)+ &
                     plotvar(i,j,k,iVar)
             end do; end do; end do
          end if
       end do
    end do; end do; end do

    do k=1,nK+1; do j=1,nJ+1; do i=1,nI+1  ! Node loop
       rr=sqrt( &
            NodeX_NB(i,j,k,iBLK)**2+ &
            NodeY_NB(i,j,k,iBLK)**2+ &
            NodeZ_NB(i,j,k,iBLK)**2)
       do iVar=1,nplotvar
          if (nodeCount(i,j,k,iVar) > 0) then
             PlotVarNodes_NBI(i,j,k,iBLK,iVar) = &
                  nodeV(i,j,k,iVar)/real(nodeCount(i,j,k,iVar))
             ! This will zero out values otherwise true with plotvar_useBody
             ! The intent of plotvar_useBody is to fill nodes inside of the body
             !   with values for plotting.  However, when allowed to go all the
             !   way to the origin, B traces will continuously loop through the
             !   body and out.  Setting the values to zero inside of 0.51 fixes it.
             if(plotvar_useBody(iVar))then
                if(rr < 0.51*Rbody .and. rr < 0.51) then
                   PlotVarNodes_NBI(i,j,k,iBLK,iVar) = 0.00
                end if
             end if
          else
             PlotVarNodes_NBI(i,j,k,iBLK,iVar) = plotvar_inBody(iVar)
          end if
       end do
    end do; end do; end do

  end subroutine plotvar_to_plotvarnodes

end subroutine write_plot_common

!==============================================================================
subroutine set_eqpar(iplotfile,neqpar,eqparnames,eqpar)

  use ModProcMH
  use ModPhysics, ONLY : g,cLIGHT,rBody,No2Io_V, UnitU_, UnitX_, UnitRho_
  use ModRaytrace, ONLY : R_raytrace                !^CFG  IF RAYTRACE
  use ModIO

  implicit none
  integer, intent(in)      :: iplotfile,neqpar
  character*10, intent(in) :: eqparnames(neqpar)
  real, intent(out)        :: eqpar(neqpar)

  integer :: ipar
  !---------------------------------------------------------------------------
  do ipar=1,neqpar
     select case(eqparnames(ipar))
     case('g')
        eqpar(ipar)=g
     case('c')
        if(plot_dimensional(plot_+iplotfile)) then
           eqpar(ipar)=Clight*No2Io_V(UnitU_)
        else
           eqpar(ipar)=Clight
        end if
     case('rbody','rBody','RBODY')
        eqpar(ipar)=rBody
        if(plot_dimensional(plot_+iplotfile))&
             eqpar(ipar)=eqpar(ipar)*No2Io_V(UnitX_)
     case('eta')
        eqpar(ipar)=0.
     case('unitx')
        eqpar(ipar)=No2Io_V(UnitX_)
     case('unitrho')
        eqpar(ipar)=No2Io_V(UnitRho_)
     case('unitv')
        eqpar(ipar)=No2Io_V(UnitU_)
     case('mu')
        eqpar(ipar)=mu_los
!!$!^CFG  IF RAYTRACE BEGIN
     case('R_ray')
        eqpar(ipar)=R_raytrace
!!$!^CFG END RAYTRACE
     case default
        eqpar(ipar)=-7777.
        if(iProc==0)write(*,*)'Error in set_eqpar: unknown eqparname=',&
             eqparnames(ipar),' for iplotfile=',iplotfile
     end select
  end do

end subroutine set_eqpar

!==============================================================================
subroutine set_plotvar(iBLK,iplotfile,nplotvar,plotvarnames,plotvar,&
     plotvar_inBody,plotvar_useBody)

  use ModProcMH
  use ModMain
  use ModVarIndexes
  use ModAdvance, ONLY : time_BLK,B0xCell_BLK,B0yCell_BLK,B0zCell_BLK, &
       State_VGB, Energy_GBI, DivB1_GB, IsConserv_CB, UseNonconservative, &
       Ex_CB, Ey_CB, Ez_CB, iTypeAdvance_B
  use ModGeometry
  use ModParallel, ONLY : BLKneighborCHILD
  use ModPhysics, ONLY : BodyRho_I, BodyP_I, OmegaBody, CellState_VI, &
       AverageIonCharge, ElectronTemperatureRatio
  use ModCT, ONLY : Bxface_BLK,Byface_BLK,Bzface_BLK       !^CFG IF CONSTRAINB
  use ModRayTrace, ONLY : ray,rayface                      !^CFG  IF RAYTRACE
  use ModUtilities, ONLY: lower_case
  use ModUser, ONLY: user_set_plot_var
  use ModIO, ONLY: NameVarUserTec_I, NameUnitUserTec_I, NameUnitUserIdl_I, &
       plot_dimensional, Plot_
  use ModNumConst, ONLY: cTiny
  use ModHallResist, ONLY: UseHallResist, hall_factor, &
       IsNewBlockHall, get_face_current
  use ModPointImplicit, ONLY: UsePointImplicit_B
  use ModMultiFluid, ONLY: extract_fluid_name, &
       TypeFluid, iFluid, iRho, iRhoUx, iRhoUy, iRhoUz, iP, iRhoIon_I

  implicit none

  integer, intent(in) :: iBLK,iPlotFile,Nplotvar
  character (LEN=10), intent(in) :: plotvarnames(Nplotvar)
  real, intent(inout) :: plotVar(-1:nI+2,-1:nJ+2,-1:nK+2,nPlotVar)
  real, intent(out)   :: plotvar_inBody(nPlotVar)
  logical, intent(out):: plotvar_useBody(nPlotVar)

  character (len=10)  :: String, NamePlotVar, NameVar

  real, dimension(-1:nI+2,-1:nJ+2,-1:nK+2) :: tmp1Var, tmp2Var

  integer :: iVar, itmp, jtmp, jVar, jFluid
  integer :: i,j,k,l, ip1,im1,jp1,jm1,kp1,km1
  real :: xfactor,yfactor,zfactor

  integer:: iDir, Di, Dj, Dk
  real :: Jx, Jy, Jz

  logical :: IsFound
  
  logical :: DoTest,DoTestMe
  character(len=*), parameter:: NameSub='set_plotvar'
  !---------------------------------------------------------------------------
  if(iBLK==BlkTest.and.iProc==ProcTest)then
     call set_oktest(NameSub,DoTest,DoTestMe)
  else
     DoTest=.false.; DoTestMe=.false.
  end if

  ! Recalculate magnetic field in block for face currents (if needed)
  IsNewBlockHall = .true.

  do iVar = 1, nPlotVar
     NamePlotVar = plotvarnames(iVar)

     ! Default values for TecPlot variable name and TecPlot and IDL unit names
     NameVarUserTec_I(iVar)  = NamePlotVar
     NameUnitUserTec_I(iVar) = ' '
     NameUnitUserIdl_I(iVar) = '?'

     call lower_case(NamePlotVar)
     String = NamePlotVar
     call extract_fluid_name(String)

     ! Set plotvar_inBody to something reasonable for inside the body.
     ! Load zeros (0) for most values - load something better for rho, p, and T
     ! We know that U,B,J are okay with zeroes, others should be changed if
     ! necessary.  Note that all variables not set to 0 should be loaded below.
     ! Note that this is used for tecplot corner extrapolation and for nothing
     ! else.
     plotvar_inBody(iVar) = 0.0

     ! Set plotvar_useBody to false unless cell values inside of the body are
     ! to be used for plotting.
     plotvar_useBody(iVar) = .false.

     select case(String)

        ! BASIC MHD variables
     case('rho')
        PlotVar(:,:,:,iVar)=State_VGB(iRho,:,:,:,iBLK)
        plotvar_inBody(iVar) = BodyRho_I(iFluid)
     case('rhoux','mx')
        if (UseRotatingFrame) then
           PlotVar(:,:,:,iVar)=State_VGB(iRhoUx,:,:,:,iBLK) &
                - State_VGB(iRho,:,:,:,iBLK)*OMEGAbody*y_BLK(:,:,:,iBLK)
        else
           PlotVar(:,:,:,iVar)=State_VGB(iRhoUx,:,:,:,iBLK)
        end if
     case('rhouy','my')
        if (UseRotatingFrame) then
           PlotVar(:,:,:,iVar)=State_VGB(iRhoUy,:,:,:,iBLK) &
                + State_VGB(iRho,:,:,:,iBLK)*OMEGAbody*x_BLK(:,:,:,iBLK)
        else
           PlotVar(:,:,:,iVar)=State_VGB(iRhoUy,:,:,:,iBLK)
        end if
     case('rhouz','mz')
        PlotVar(:,:,:,iVar)=State_VGB(iRhoUz,:,:,:,iBLK)
     case('bx')
        plotvar_useBody(iVar) = NameThisComp/='SC'
        PlotVar(:,:,:,iVar)=State_VGB(Bx_,:,:,:,iBLK)+B0xCell_BLK(:,:,:,iBLK)
     case('by')
        plotvar_useBody(iVar) = NameThisComp/='SC'
        PlotVar(:,:,:,iVar)=State_VGB(By_,:,:,:,iBLK)+B0yCell_BLK(:,:,:,iBLK)
     case('bz')
        plotvar_useBody(iVar) = NameThisComp/='SC'
        PlotVar(:,:,:,iVar)=State_VGB(Bz_,:,:,:,iBLK)+B0zCell_BLK(:,:,:,iBLK)

     case('bxl')                                 !^CFG IF CONSTRAINB BEGIN
        PlotVar(1:nI,1:nJ,1:nK,iVar)=BxFace_BLK(1:nI,1:nJ,1:nK,iBLK)
     case('bxr')
        PlotVar(1:nI,1:nJ,1:nK,iVar)=BxFace_BLK(2:nI+1,1:nJ,1:nK,iBLK)
     case('byl')
        PlotVar(1:nI,1:nJ,1:nK,iVar)=ByFace_BLK(1:nI,1:nJ,1:nK,iBLK)
     case('byr')
        PlotVar(1:nI,1:nJ,1:nK,iVar)=ByFace_BLK(1:nI,2:nJ+1,1:nK,iBLK)
     case('bzl')
        PlotVar(1:nI,1:nJ,1:nK,iVar)=BzFace_BLK(1:nI,1:nJ,1:nK,iBLK)
     case('bzr')
        PlotVar(1:nI,1:nJ,1:nK,iVar)=BzFace_BLK(1:nI,1:nJ,2:nK+1,iBLK)
        !                                        !^CFG END CONSTRAINB
     case('e')
        PlotVar(:,:,:,iVar) = Energy_GBI(:,:,:,iBLK,iFluid)
        ! Add (B0+B1)^2 - B1^2 so the energy contains B0
        if(TypeFluid == 'ion') &
             PlotVar(:,:,:,iVar) = PlotVar(:,:,:,iVar)+0.5*(&
             (State_VGB(Bx_,:,:,:,iBLK)+B0xCell_BLK(:,:,:,iBLK))**2+&
             (State_VGB(By_,:,:,:,iBLK)+B0yCell_BLK(:,:,:,iBLK))**2+&
             (State_VGB(Bz_,:,:,:,iBLK)+B0zCell_BLK(:,:,:,iBLK))**2 &
             -State_VGB(Bx_,:,:,:,iBLK)**2 &
             -State_VGB(By_,:,:,:,iBLK)**2 &
             -State_VGB(Bz_,:,:,:,iBLK)**2)
     case('p','pth')
        PlotVar(:,:,:,iVar) = State_VGB(iP,:,:,:,iBLK)
        plotvar_inBody(iVar) = BodyP_I(iFluid)

        ! EXTRA MHD variables

     case('n','t','temp')
        ! Calculate the number density
        if(UseMultiSpecies)then
           PlotVar(:,:,:,iVar)=0.0
           do jVar = SpeciesFirst_, SpeciesLast_
              PlotVar(:,:,:,iVar) = PlotVar(:,:,:,iVar) + &
                   State_VGB(jVar,:,:,:,iBLK)/MassSpecies_V(jVar)
           end do
        else if(UseMultiIon .and. TypeFluid_I(iFluid) == 'ion')then
           ! This can only occur for iFluid = 1 being the total ion fluid
           ! sum(n_i) = sum(rho_i/M_i) = rho/M_1 + sum_2 rho_i*(1/M_i - 1/M_1)
           PlotVar(:,:,:,iVar) = State_VGB(Rho_,:,:,:,iBLK)/MassFluid_I(1)
           do jFluid = 2, nIonFluid
              PlotVar(:,:,:,iVar) = PlotVar(:,:,:,iVar) + &
                   State_VGB(iRhoIon_I(jFluid),:,:,:,iBLK) &
                   *(1/MassFluid_I(jFluid) - 1/MassFluid_I(1))
           end do
        else
           PlotVar(:,:,:,iVar) = State_VGB(iRho,:,:,:,iBLK)/MassFluid_I(iFluid)
        end if

        ! Calculate temperature from P = n*k*T + ne*k*Te = n*k*T*(1+ne/n*Te/T)
        if(String /= 'n') PlotVar(:,:,:,iVar) = &
             State_VGB(iP,:,:,:,iBLK) / PlotVar(:,:,:,iVar) &
             /(1+AverageIonCharge*ElectronTemperatureRatio)
     case('ux')
        if (UseRotatingFrame) then
           PlotVar(:,:,:,iVar) = &
                State_VGB(iRhoUx,:,:,:,iBLK)/State_VGB(iRho,:,:,:,iBLK) &
                - OMEGAbody*y_BLK(:,:,:,iBLK)
        else
           PlotVar(:,:,:,iVar) = &
                State_VGB(iRhoUx,:,:,:,iBLK)/State_VGB(iRho,:,:,:,iBLK)
        end if
     case('uy')
        if (UseRotatingFrame) then
           PlotVar(:,:,:,iVar) = &
                State_VGB(iRhoUy,:,:,:,iBLK)/State_VGB(iRho,:,:,:,iBLK) &
                + OMEGAbody*x_BLK(:,:,:,iBLK)
        else
           PlotVar(:,:,:,iVar) = &
                State_VGB(iRhoUy,:,:,:,iBLK) / State_VGB(iRho,:,:,:,iBLK)
        end if
     case('uz')
        PlotVar(:,:,:,iVar) = &
             State_VGB(iRhoUz,:,:,:,iBLK) / State_VGB(iRho,:,:,:,iBLK)
     case('b1x')
        PlotVar(:,:,:,iVar) = State_VGB(Bx_,:,:,:,iBLK)
     case('b1y')
        PlotVar(:,:,:,iVar) = State_VGB(By_,:,:,:,iBLK)
     case('b1z')
        PlotVar(:,:,:,iVar) = State_VGB(Bz_,:,:,:,iBLK)
     case('jx')
        if(UseCovariant)then                       
           call covar_curlb_plotvar(x_,iBLK,PlotVar(:,:,:,iVar))  
        else                                       
           if(true_BLK(iBLK))then                  
              PlotVar(0:nI+1,0:nJ+1,0:nK+1,iVar)=0.5*(&
                   (State_VGB(Bz_, 0:nI+1, 1:nJ+2, 0:nK+1,iBLK) &
                   -State_VGB(Bz_, 0:nI+1,-1:nJ  , 0:nK+1,iBLK))/dy_BLK(iBLK)-&
                   (State_VGB(By_, 0:nI+1, 0:nJ+1, 1:nK+2,iBLK) &
                   -State_VGB(By_, 0:nI+1, 0:nJ+1,-1:nK  ,iBLK))/dz_BLK(iBLK))
           else
              do k=0,nK+1; do j=0,nJ+1; do i=0,nI+1  ! Cell loop
                 if( .not.true_cell(i,j,k,iBLK) ) CYCLE
                 
                 ip1=i+1; im1=i-1; jp1=j+1; jm1=j-1; kp1=k+1; km1=k-1
                 if(.not.true_cell(ip1,j,k,iBLK)) ip1=i
                 if(.not.true_cell(im1,j,k,iBLK)) im1=i
                 if(.not.true_cell(i,jp1,k,iBLK)) jp1=j
                 if(.not.true_cell(i,jm1,k,iBLK)) jm1=j
                 if(.not.true_cell(i,j,kp1,iBLK)) kp1=k
                 if(.not.true_cell(i,j,km1,iBLK)) km1=k
                 if(ip1==im1 .or. jp1==jm1 .or. kp1==km1) CYCLE
                 
                 xfactor=1.; yfactor=1.; zfactor=1.
                 if((ip1-im1)==1) xfactor=2.
                 if((jp1-jm1)==1) yfactor=2.
                 if((kp1-km1)==1) zfactor=2.
                 
                 PlotVar(i,j,k,iVar)=0.5*(&
                      (State_VGB(Bz_,i  ,jp1,k  ,iBLK) &
                      -State_VGB(Bz_,i  ,jm1,k  ,iBLK))*yfactor / dy_BLK(iBLK) - &
                      (State_VGB(By_,i  ,j  ,kp1,iBLK) &
                      -State_VGB(By_,i  ,j  ,km1,iBLK))*zfactor / dz_BLK(iBLK))
              end do; end do; end do
           end if                            
           continue
        end if                               
     case('jy')
        if(UseCovariant)then                  
           call covar_curlb_plotvar(y_,iBLK,PlotVar(:,:,:,iVar))   
        else                                 
           if(true_BLK(iBLK))then            
              PlotVar(0:nI+1,0:nJ+1,0:nK+1,iVar)=0.5*(&
                   (State_VGB(Bx_, 0:nI+1, 0:nJ+1, 1:nK+2,iBLK) &
                   -State_VGB(Bx_, 0:nI+1, 0:nJ+1,-1:nK  ,iBLK))/dz_BLK(iBLK)-&
                   (State_VGB(Bz_, 1:nI+2, 0:nJ+1, 0:nK+1,iBLK) &
                   -State_VGB(Bz_,-1:nI  , 0:nJ+1, 0:nK+1,iBLK))/dx_BLK(iBLK))
           else
              do k=0,nK+1; do j=0,nJ+1; do i=0,nI+1  ! Cell loop
                 if( .not.true_cell(i,j,k,iBLK) ) CYCLE
                 
                 ip1=i+1; im1=i-1; jp1=j+1; jm1=j-1; kp1=k+1; km1=k-1
                 if(.not.true_cell(ip1,j,k,iBLK)) ip1=i
                 if(.not.true_cell(im1,j,k,iBLK)) im1=i
                 if(.not.true_cell(i,jp1,k,iBLK)) jp1=j
                 if(.not.true_cell(i,jm1,k,iBLK)) jm1=j
                 if(.not.true_cell(i,j,kp1,iBLK)) kp1=k
                 if(.not.true_cell(i,j,km1,iBLK)) km1=k
                 if(ip1==im1 .or. jp1==jm1 .or. kp1==km1) CYCLE
                 
                 xfactor=1.; yfactor=1.; zfactor=1.
                 if((ip1-im1)==1) xfactor=2.
                 if((jp1-jm1)==1) yfactor=2.
                 if((kp1-km1)==1) zfactor=2.
                 
                 PlotVar(i,j,k,iVar)=0.5*(&
                      (State_VGB(Bx_,i  ,j  ,kp1,iBLK) &
                      -State_VGB(Bx_,i  ,j  ,km1,iBLK))*zfactor/dz_BLK(iBLK)-&
                      (State_VGB(Bz_,ip1,j  ,k  ,iBLK) &
                      -State_VGB(Bz_,im1,j  ,k  ,iBLK))*xfactor/dx_BLK(iBLK))
              end do; end do; end do
           endif                                   
           continue
        end if                                     

     case('jz')
        if(UseCovariant)then                       
           call covar_curlb_plotvar(z_,iBLK,PlotVar(:,:,:,iVar))  
        else                                       
           if(true_BLK(iBLK))then                  
              PlotVar(0:nI+1,0:nJ+1,0:nK+1,iVar)=0.5*(&
                   (State_VGB(By_, 1:nI+2,0:nJ+1,0:nK+1,iBLK) &
                   -State_VGB(By_,-1:nI  ,0:nJ+1,0:nK+1,iBLK))/dx_BLK(iBLK) - &
                   (State_VGB(Bx_,0:nI+1, 1:nJ+2,0:nK+1,iBLK) &
                   -State_VGB(Bx_,0:nI+1,-1:nJ  ,0:nK+1,iBLK))/dy_BLK(iBLK))
           else
              do k=0,nK+1; do j=0,nJ+1; do i=0,nI+1  ! Cell loop
                 if( .not.true_cell(i,j,k,iBLK) ) CYCLE
                 
                 ip1=i+1; im1=i-1; jp1=j+1; jm1=j-1; kp1=k+1; km1=k-1
                 if(.not.true_cell(ip1,j,k,iBLK)) ip1=i
                 if(.not.true_cell(im1,j,k,iBLK)) im1=i
                 if(.not.true_cell(i,jp1,k,iBLK)) jp1=j
                 if(.not.true_cell(i,jm1,k,iBLK)) jm1=j
                 if(.not.true_cell(i,j,kp1,iBLK)) kp1=k
                 if(.not.true_cell(i,j,km1,iBLK)) km1=k
                 if(ip1==im1 .or. jp1==jm1 .or. kp1==km1) CYCLE

                 xfactor=1.; yfactor=1.; zfactor=1.
                 if((ip1-im1)==1) xfactor=2.
                 if((jp1-jm1)==1) yfactor=2.
                 if((kp1-km1)==1) zfactor=2.
                 
                 PlotVar(i,j,k,iVar)=0.5*(&
                      (State_VGB(By_,ip1,j  ,k  ,iBLK) &
                      -State_VGB(By_,im1,j  ,k  ,iBLK))*xfactor/dx_BLK(iBLK)-&
                      (State_VGB(Bx_,i  ,jp1,k  ,iBLK) &
                      -State_VGB(Bx_,i  ,jm1,k  ,iBLK))*yfactor/dy_BLK(iBLK))
              end do; end do; end do
           end if                                  
           continue
        end if                                     
     case('jxe','jye','jze','jxw','jyw','jzw', &
          'jxs','jys','jzs','jxn','jyn','jzn', &
          'jxb','jyb','jzb','jxt','jyt','jzt')
        Di=0; Dj=0; Dk=0
        select case(String(3:3))
        case('e')
           iDir=1
        case('w')
           iDir=1; Di=1
        case('s')
           iDir=2
        case('n')
           iDir=2; Dj=1
        case('b')
           iDir=3
        case('t')
           iDir=3; Dk=1
        end select
        do k=1,nK; do j=1,nJ; do i=1,nI
           call get_face_current(iDir, i+Di, j+Dj, k+Dk, iBlk, Jx, Jy, Jz)
           select case(String(2:2))
           case('x')
              PlotVar(i,j,k,iVar)=Jx
           case('y')
              PlotVar(i,j,k,iVar)=Jy
           case('z')
              PlotVar(i,j,k,iVar)=Jz
           end select
        end do; end do; end do
     case('enumx')
        PlotVar(1:nI,1:nJ,1:nK,iVar)= Ex_CB(:,:,:,iBLK)
     case('enumy')
        PlotVar(1:nI,1:nJ,1:nK,iVar)= Ey_CB(:,:,:,iBLK)
     case('enumz')
        PlotVar(1:nI,1:nJ,1:nK,iVar)= Ez_CB(:,:,:,iBLK)
     case('ex')
        PlotVar(:,:,:,iVar)= &
             ( State_VGB(iRhoUz,:,:,:,iBLK) &
             * ( State_VGB(By_,:,:,:,iBLK) + B0yCell_BLK(:,:,:,iBLK)) &
             - State_VGB(iRhoUy,:,:,:,iBLK) &
             * ( State_VGB(Bz_,:,:,:,iBLK) + B0zCell_BLK(:,:,:,iBLK)) &
             ) / State_VGB(iRho,:,:,:,iBLK) 
     case('ey')
        PlotVar(:,:,:,iVar)= ( State_VGB(iRhoUx,:,:,:,iBLK)* &
             (State_VGB(Bz_,:,:,:,iBLK)+B0zCell_BLK(:,:,:,iBLK)) &
             -State_VGB(iRhoUz,:,:,:,iBLK)* &
             (State_VGB(Bx_,:,:,:,iBLK)+B0xCell_BLK(:,:,:,iBLK)))/ &
             State_VGB(iRho,:,:,:,iBLK) 
     case('ez')
        PlotVar(:,:,:,iVar)= ( State_VGB(iRhoUy,:,:,:,iBLK)* &
             (State_VGB(Bx_,:,:,:,iBLK)+B0xCell_BLK(:,:,:,iBLK)) &
             -State_VGB(iRhoUx,:,:,:,iBLK)* &
             (State_VGB(By_,:,:,:,iBLK)+B0yCell_BLK(:,:,:,iBLK)))/ &
             State_VGB(iRho,:,:,:,iBLK) 
     case('pvecx')
        PlotVar(:,:,:,iVar) = ( &
             ( (State_VGB(Bx_,:,:,:,iBLK)+ B0xCell_BLK(:,:,:,iBLK))**2  &
             + (State_VGB(By_,:,:,:,iBLK)+ B0yCell_BLK(:,:,:,iBLK))**2  &
             + (State_VGB(Bz_,:,:,:,iBLK)+ B0zCell_BLK(:,:,:,iBLK))**2) * &
             State_VGB(iRhoUx,:,:,:,iBLK) &
             -((State_VGB(Bx_,:,:,:,iBLK)+B0xCell_BLK(:,:,:,iBLK))* &
             State_VGB(iRhoUx,:,:,:,iBLK) + &
             (State_VGB(By_,:,:,:,iBLK)+B0yCell_BLK(:,:,:,iBLK))* &
             State_VGB(iRhoUy,:,:,:,iBLK) + &
             (State_VGB(Bz_,:,:,:,iBLK)+B0zCell_BLK(:,:,:,iBLK))* &
             State_VGB(iRhoUz,:,:,:,iBLK)) * &
             (State_VGB(Bx_,:,:,:,iBLK)+B0xCell_BLK(:,:,:,iBLK) ) ) &
             / State_VGB(iRho,:,:,:,iBLK)
     case('pvecy')
        PlotVar(:,:,:,iVar) = ( &
             ((State_VGB(Bx_,:,:,:,iBLK)+ B0xCell_BLK(:,:,:,iBLK))**2 + &
             (State_VGB(By_,:,:,:,iBLK)+ B0yCell_BLK(:,:,:,iBLK))**2 + &
             (State_VGB(Bz_,:,:,:,iBLK)+ B0zCell_BLK(:,:,:,iBLK))**2) * &
             State_VGB(iRhoUy,:,:,:,iBLK) &
             -((State_VGB(Bx_,:,:,:,iBLK)+B0xCell_BLK(:,:,:,iBLK))* &
             State_VGB(iRhoUx,:,:,:,iBLK) + &
             (State_VGB(By_,:,:,:,iBLK)+B0yCell_BLK(:,:,:,iBLK))* &
             State_VGB(iRhoUy,:,:,:,iBLK) + &
             (State_VGB(Bz_,:,:,:,iBLK)+B0zCell_BLK(:,:,:,iBLK))* &
             State_VGB(iRhoUz,:,:,:,iBLK)) * &
             (State_VGB(By_,:,:,:,iBLK)+B0yCell_BLK(:,:,:,iBLK) ) ) &
             / State_VGB(iRho,:,:,:,iBLK)
     case('pvecz')
        PlotVar(:,:,:,iVar) = ( &
             ((State_VGB(Bx_,:,:,:,iBLK)+ B0xCell_BLK(:,:,:,iBLK))**2 + &
             (State_VGB(By_,:,:,:,iBLK)+ B0yCell_BLK(:,:,:,iBLK))**2 + &
             (State_VGB(Bz_,:,:,:,iBLK)+ B0zCell_BLK(:,:,:,iBLK))**2) * &
             State_VGB(iRhoUz,:,:,:,iBLK) &
             -((State_VGB(Bx_,:,:,:,iBLK)+B0xCell_BLK(:,:,:,iBLK))* &
             State_VGB(iRhoUx,:,:,:,iBLK) + &
             (State_VGB(By_,:,:,:,iBLK)+B0yCell_BLK(:,:,:,iBLK))* &
             State_VGB(iRhoUy,:,:,:,iBLK) + &
             (State_VGB(Bz_,:,:,:,iBLK)+B0zCell_BLK(:,:,:,iBLK))* &
             State_VGB(iRhoUz,:,:,:,iBLK)) * &
             (State_VGB(Bz_,:,:,:,iBLK)+B0zCell_BLK(:,:,:,iBLK) ) ) &
             / State_VGB(iRho,:,:,:,iBLK)

        ! Radial component variables

     case('ur')
        PlotVar(:,:,:,iVar) = &
             ( State_VGB(iRhoUx,:,:,:,iBLK)*x_BLK(:,:,:,iBLK) & 
             + State_VGB(iRhoUy,:,:,:,iBLK)*y_BLK(:,:,:,iBLK) & 
             + State_VGB(iRhoUz,:,:,:,iBLK)*z_BLK(:,:,:,iBLK) &
             ) / (State_VGB(iRho,:,:,:,iBLK)*R_BLK(:,:,:,iBLK))
     case('rhour','mr')
        PlotVar(:,:,:,iVar) = &
             ( State_VGB(iRhoUx,:,:,:,iBLK)*x_BLK(:,:,:,iBLK) & 
             + State_VGB(iRhoUy,:,:,:,iBLK)*y_BLK(:,:,:,iBLK) & 
             + State_VGB(iRhoUz,:,:,:,iBLK)*z_BLK(:,:,:,iBLK) &
             ) / R_BLK(:,:,:,iBLK)
     case('br')
        plotvar_useBody(iVar) = .true.
        PlotVar(:,:,:,iVar)=( &
             ( State_VGB(Bx_,:,:,:,iBLK)+B0xCell_BLK(:,:,:,iBLK)) &
             *X_BLK(:,:,:,iBLK)                         &  
             +(State_VGB(By_,:,:,:,iBLK)+B0yCell_BLK(:,:,:,iBLK)) &
             *Y_BLK(:,:,:,iBLK)                         &
             +(State_VGB(Bz_,:,:,:,iBLK)+B0zCell_BLK(:,:,:,iBLK)) &
             *Z_BLK(:,:,:,iBLK) ) / R_BLK(:,:,:,iBLK) 
     case('b1r')
        PlotVar(:,:,:,iVar)= &
             ( State_VGB(Bx_,:,:,:,iBLK)*x_BLK(:,:,:,iBLK) &
             + State_VGB(By_,:,:,:,iBLK)*y_BLK(:,:,:,iBLK) &
             + State_VGB(Bz_,:,:,:,iBLK)*z_BLK(:,:,:,iBLK) &
             ) / R_BLK(:,:,:,iBLK)                                 
     case('jr')
        if(UseCovariant)then                       
           call covar_curlbr_plotvar(iBLK,PlotVar(:,:,:,iVar))  
        else                                       
           PlotVar(0:nI+1,0:nJ+1,0:nK+1,iVar) = &  
                0.5 / R_BLK(0:nI+1,0:nJ+1,0:nK+1,iBLK) * &
                ( ( &
                ( State_VGB(Bz_,0:nI+1, 1:nJ+2, 0:nK+1,iBLK) & 
                - State_VGB(Bz_,0:nI+1,-1:nJ  , 0:nK+1,iBLK))/dy_BLK(iBLK) - &
                ( State_VGB(By_,0:nI+1, 0:nJ+1, 1:nK+2,iBLK) &
                - State_VGB(By_,0:nI+1, 0:nJ+1,-1:nK  ,iBLK))/dz_BLK(iBLK)   &
                ) * x_BLK(0:nI+1,0:nJ+1,0:nK+1,iBLK) &
                + ( &
                ( State_VGB(Bx_, 0:nI+1,0:nJ+1, 1:nK+2,iBLK) &
                - State_VGB(Bx_, 0:nI+1,0:nJ+1,-1:nK  ,iBLK))/dz_BLK(iBLK) - &
                ( State_VGB(Bz_, 1:nI+2,0:nJ+1, 0:nK+1,iBLK) &
                - State_VGB(Bz_,-1:nI  ,0:nJ+1, 0:nK+1,iBLK))/dx_BLK(iBLK)   &
                ) * y_BLK(0:nI+1,0:nJ+1,0:nK+1,iBLK) &
                + ( &
                ( State_VGB(By_, 1:nI+2, 0:nJ+1,0:nK+1,iBLK) &
                - State_VGB(By_,-1:nI  , 0:nJ+1,0:nK+1,iBLK))/dx_BLK(iBLK) - &
                ( State_VGB(Bx_, 0:nI+1, 1:nJ+2,0:nK+1,iBLK) &
                - State_VGB(Bx_, 0:nI+1,-1:nJ  ,0:nK+1,iBLK))/dy_BLK(iBLK)   &
                ) * z_BLK(0:nI+1,0:nJ+1,0:nK+1,iBLK) )     
           continue
        end if                                             
     case('er')
        PlotVar(:,:,:,iVar)=( ( State_VGB(iRhoUz,:,:,:,iBLK)* &
             (State_VGB(By_,:,:,:,iBLK)+B0yCell_BLK(:,:,:,iBLK)) &
             -State_VGB(iRhoUy,:,:,:,iBLK)* &
             (State_VGB(Bz_,:,:,:,iBLK)+B0zCell_BLK(:,:,:,iBLK))) &
             *x_BLK(:,:,:,iBLK) &
             +( State_VGB(iRhoUx,:,:,:,iBLK)* &
             (State_VGB(Bz_,:,:,:,iBLK)+B0zCell_BLK(:,:,:,iBLK)) &
             -State_VGB(iRhoUz,:,:,:,iBLK)* &
             (State_VGB(Bx_,:,:,:,iBLK)+B0xCell_BLK(:,:,:,iBLK))) &
             *y_BLK(:,:,:,iBLK) &
             +( State_VGB(iRhoUy,:,:,:,iBLK)* &
             (State_VGB(Bx_,:,:,:,iBLK)+B0xCell_BLK(:,:,:,iBLK)) &
             -State_VGB(iRhoUx,:,:,:,iBLK)* &
             (State_VGB(By_,:,:,:,iBLK)+B0yCell_BLK(:,:,:,iBLK))) &
             *z_BLK(:,:,:,iBLK) )/State_VGB(iRho,:,:,:,iBLK) 
     case('pvecr')
        tmp1Var = &
             (State_VGB(Bx_,:,:,:,iBLK)+B0xCell_BLK(:,:,:,iBLK))**2 + &
             (State_VGB(By_,:,:,:,iBLK)+B0yCell_BLK(:,:,:,iBLK))**2 + &
             (State_VGB(Bz_,:,:,:,iBLK)+B0zCell_BLK(:,:,:,iBLK))**2 
        tmp2Var = &
             (State_VGB(Bx_,:,:,:,iBLK)+B0xCell_BLK(:,:,:,iBLK))* &
             State_VGB(iRhoUx,:,:,:,iBLK) + &
             (State_VGB(By_,:,:,:,iBLK)+B0yCell_BLK(:,:,:,iBLK))* &
             State_VGB(iRhoUy,:,:,:,iBLK) + &
             (State_VGB(Bz_,:,:,:,iBLK)+B0zCell_BLK(:,:,:,iBLK))* &
             State_VGB(iRhoUz,:,:,:,iBLK) 
        PlotVar(:,:,:,iVar)=( ( tmp1Var*State_VGB(iRhoUx,:,:,:,iBLK) &
             -tmp2Var*(State_VGB(Bx_,:,:,:,iBLK)+ &
             B0xCell_BLK(:,:,:,iBLK)))*X_BLK(:,:,:,iBLK) &
             +( tmp1Var*State_VGB(iRhoUy,:,:,:,iBLK) &
             -  tmp2Var*(State_VGB(By_,:,:,:,iBLK)+ &
             B0yCell_BLK(:,:,:,iBLK)))*Y_BLK(:,:,:,iBLK) &  
             +( tmp1Var*State_VGB(iRhoUz,:,:,:,iBLK) &
             -  tmp2Var*(State_VGB(Bz_,:,:,:,iBLK)+ &
             B0zCell_BLK(:,:,:,iBLK)))*Z_BLK(:,:,:,iBLK) )&   
             /(State_VGB(iRho,:,:,:,iBLK)*R_BLK(:,:,:,iBLK))
     case('b2ur')
        tmp1Var = &
             (State_VGB(Bx_,:,:,:,iBLK)+B0xCell_BLK(:,:,:,iBLK))**2 + &
             (State_VGB(By_,:,:,:,iBLK)+B0yCell_BLK(:,:,:,iBLK))**2 + &
             (State_VGB(Bz_,:,:,:,iBLK)+B0zCell_BLK(:,:,:,iBLK))**2  
        PlotVar(:,:,:,iVar)=0.5* &
             ( tmp1Var*State_VGB(iRhoUx,:,:,:,iBLK)*X_BLK(:,:,:,iBLK) &
             + tmp1Var*State_VGB(iRhoUy,:,:,:,iBLK)*Y_BLK(:,:,:,iBLK) &  
             + tmp1Var*State_VGB(iRhoUz,:,:,:,iBLK)*Z_BLK(:,:,:,iBLK) &   
             )/(State_VGB(iRho,:,:,:,iBLK)*R_BLK(:,:,:,iBLK))
     case('divb','divb_cd','divb_ct')
        if(UseCovariant)&                            
             call stop_mpi('When UseCovariant=T use absdivb indstead of divb')
                                                     
        
        if(String == 'divb_cd' .or. (String == 'divb' &
             .and..not.UseConstrainB &               !^CFG IF CONSTRAINB
             ))then
           ! Div B from central differences
           PlotVar(0:nI+1,0:nJ+1,0:nK+1,iVar)=0.5*vInv_CB(1,1,1,iBLK)*(  &
                fAx_BLK(iBLK)*(State_VGB(Bx_,1:nI+2,0:nJ+1,0:nK+1,iBLK)-  &
                State_VGB(Bx_,-1:nI,0:nJ+1,0:nK+1,iBLK))+ &
                fAy_BLK(iBLK)*(State_VGB(By_,0:nI+1,1:nJ+2,0:nK+1,iBLK)-  &
                State_VGB(By_,0:nI+1,-1:nJ,0:nK+1,iBLK))+ &
                fAz_BLK(iBLK)*(State_VGB(Bz_,0:nI+1,0:nJ+1,1:nk+2,iBLK)-  &
                State_VGB(Bz_,0:nI+1,0:nJ+1,-1:nK,iBLK)))
        else if(UseConstrainB)then                   !^CFG IF CONSTRAINB BEGIN
           ! Div B from face fluxes
           PlotVar(0:nI+1,0:nJ+1,0:nK+1,iVar)= &
                (Bxface_BLK(1:nI+2  ,0:nJ+1  ,0:nK+1  ,iBLK)              &
                -Bxface_BLK(0:nI+1  ,0:nJ+1  ,0:nK+1  ,iBLK))/dx_BLK(iBLK)&
                +(Byface_BLK(0:nI+1  ,1:nJ+2  ,0:nK+1  ,iBLK)              &
                -Byface_BLK(0:nI+1  ,0:nJ+1  ,0:nK+1  ,iBLK))/dy_BLK(iBLK)&
                +(Bzface_BLK(0:nI+1  ,0:nJ+1  ,1:nk+2  ,iBLK)              &
                -Bzface_BLK(0:nI+1  ,0:nJ+1  ,0:nK+1  ,iBLK))/dz_BLK(iBLK)
           !                                         !^CFG END CONSTRAINB
        else
           ! Cell corner centered div B from cell centers
           PlotVar(0:nI+1  ,0:nJ+1  ,0:nK+1,iVar)= 0.25*(&
                (State_VGB(Bx_,0:nI+1  ,0:nJ+1  ,0:nK+1  ,iBLK)  &
                +State_VGB(Bx_,0:nI+1  ,-1:nJ   ,0:nK+1  ,iBLK)  &
                +State_VGB(Bx_,0:nI+1  ,0:nJ+1  ,-1:nK   ,iBLK)  &
                +State_VGB(Bx_,0:nI+1  ,-1:nJ   ,-1:nK   ,iBLK)  &
                -State_VGB(Bx_,-1:nI   ,0:nJ+1  ,0:nK+1  ,iBLK)  &
                -State_VGB(Bx_,-1:nI   ,-1:nJ   ,0:nK+1  ,iBLK)  &
                -State_VGB(Bx_,-1:nI   ,0:nJ+1  ,-1:nK   ,iBLK)  &
                -State_VGB(Bx_,-1:nI   ,-1:nJ   ,-1:nK   ,iBLK))/dx_BLK(iBLK) &
                +(State_VGB(By_,0:nI+1  ,0:nJ+1  ,0:nK+1  ,iBLK)  &
                +State_VGB(By_,-1:nI   ,0:nJ+1  ,0:nK+1  ,iBLK)  &
                +State_VGB(By_,0:nI+1  ,0:nJ+1  ,-1:nK   ,iBLK)  &
                +State_VGB(By_,-1:nI   ,0:nJ+1  ,-1:nK   ,iBLK)  &
                -State_VGB(By_,0:nI+1  ,-1:nJ   ,0:nK+1  ,iBLK)  &
                -State_VGB(By_,-1:nI   ,-1:nJ   ,0:nK+1  ,iBLK)  &
                -State_VGB(By_,0:nI+1  ,-1:nJ   ,-1:nK   ,iBLK)  &
                -State_VGB(By_,-1:nI   ,-1:nJ   ,-1:nK   ,iBLK))/dy_BLK(iBLK) &
                +(State_VGB(Bz_,0:nI+1  ,0:nJ+1  ,0:nK+1  ,iBLK)  &
                +State_VGB(Bz_,-1:nI   ,0:nJ+1  ,0:nK+1  ,iBLK)  &
                +State_VGB(Bz_,0:nI+1  ,-1:nJ   ,0:nK+1  ,iBLK)  &
                +State_VGB(Bz_,-1:nI   ,-1:nJ   ,0:nK+1  ,iBLK)  &
                -State_VGB(Bz_,0:nI+1  ,0:nJ+1  ,-1:nK   ,iBLK)  &
                -State_VGB(Bz_,-1:nI   ,0:nJ+1  ,-1:nK   ,iBLK)  &
                -State_VGB(Bz_,0:nI+1  ,-1:nJ   ,-1:nK   ,iBLK)  &
                -State_VGB(Bz_,-1:nI   ,-1:nJ   ,-1:nK   ,iBLK))/dz_BLK(iBLK))
        endif
        if(.not.true_BLK(iBLK))then
           where(.not.true_cell(:,:,:,iBLK))PlotVar(:,:,:,iVar)=0.0
        endif

     case('absdivb')
        PlotVar(0:nI+1,0:nJ+1,0:nK+1,iVar) = &
             abs(DivB1_GB(0:nI+1,0:nJ+1,0:nK+1,iBLK))
        if(.not.true_BLK(iBLK))then
           where(.not.true_cell(:,:,:,iBLK)) PlotVar(:,:,:,iVar)=0.0
        endif
!!$!^CFG  IF RAYTRACE BEGIN
        ! BASIC RAYTRACE variables

     case('theta1','theta2','phi1','phi2','status')
        select case(String)
        case ('theta1')
           itmp = 1 ; jtmp = 1
        case ('theta2')
           itmp = 1 ; jtmp = 2
        case ('phi1')
           itmp = 2 ; jtmp = 1
        case ('phi2')
           itmp = 2 ; jtmp = 2
        case ('status')
           itmp = 3 ; jtmp = 1
        end select

        PlotVar(1:nI,1:nJ,1:nK,iVar)=ray(itmp,jtmp,1:nI,1:nJ,1:nK,iBLK)
        ! Now load the face ghost cells with the first computation 
        ! cell on each face.  This is a bad approximation but is 
        ! needed for Tecplot.  It will be fixed later using message 
        ! passing
        PlotVar(1:nI,1:nJ,0   ,iVar)=ray(itmp,jtmp,1:nI,1:nJ,1   ,iBLK)
        PlotVar(1:nI,1:nJ,nK+1,iVar)=ray(itmp,jtmp,1:nI,1:nJ,nK  ,iBLK)
        PlotVar(1:nI,0   ,1:nK,iVar)=ray(itmp,jtmp,1:nI,1   ,1:nK,iBLK)
        PlotVar(1:nI,nJ+1,1:nK,iVar)=ray(itmp,jtmp,1:nI,nJ  ,1:nK,iBLK)
        PlotVar(0   ,1:nJ,1:nK,iVar)=ray(itmp,jtmp,1   ,1:nJ,1:nK,iBLK)
        PlotVar(nI+1,1:nJ,1:nK,iVar)=ray(itmp,jtmp,nI  ,1:nJ,1:nK,iBLK)
        ! Do edges
        PlotVar(1:nI,0   ,0   ,iVar)=ray(itmp,jtmp,1:nI,1   ,1   ,iBLK)
        PlotVar(1:nI,nJ+1,nK+1,iVar)=ray(itmp,jtmp,1:nI,nJ  ,nK  ,iBLK)
        PlotVar(1:nI,nJ+1,0   ,iVar)=ray(itmp,jtmp,1:nI,nJ  ,1   ,iBLK)
        PlotVar(1:nI,0   ,nK+1,iVar)=ray(itmp,jtmp,1:nI,1   ,nK  ,iBLK)
        PlotVar(0   ,0   ,1:nK,iVar)=ray(itmp,jtmp,1   ,1   ,1:nK,iBLK)
        PlotVar(nI+1,nJ+1,1:nK,iVar)=ray(itmp,jtmp,nI  ,nJ  ,1:nK,iBLK)
        PlotVar(nI+1,0   ,1:nK,iVar)=ray(itmp,jtmp,nI  ,1   ,1:nK,iBLK)
        PlotVar(0   ,nJ+1,1:nK,iVar)=ray(itmp,jtmp,1   ,nJ  ,1:nK,iBLK)
        PlotVar(0   ,1:nJ,0   ,iVar)=ray(itmp,jtmp,1   ,1:nJ,1   ,iBLK)
        PlotVar(nI+1,1:nJ,nK+1,iVar)=ray(itmp,jtmp,nI  ,1:nJ,nK  ,iBLK)
        PlotVar(nI+1,1:nJ,0   ,iVar)=ray(itmp,jtmp,nI  ,1:nJ,1   ,iBLK)
        PlotVar(0   ,1:nJ,nK+1,iVar)=ray(itmp,jtmp,1   ,1:nJ,nK  ,iBLK)
        ! Do corners
        PlotVar(0   ,0   ,0   ,iVar)=ray(itmp,jtmp,1   ,1   ,1   ,iBLK)
        PlotVar(0   ,nJ+1,0   ,iVar)=ray(itmp,jtmp,1   ,nJ  ,1   ,iBLK)
        PlotVar(0   ,0   ,nK+1,iVar)=ray(itmp,jtmp,1   ,1   ,nK  ,iBLK)
        PlotVar(0   ,nJ+1,nK+1,iVar)=ray(itmp,jtmp,1   ,nJ  ,nK  ,iBLK)
        PlotVar(nI+1,0   ,0   ,iVar)=ray(itmp,jtmp,nI  ,1   ,1   ,iBLK)
        PlotVar(nI+1,nJ+1,0   ,iVar)=ray(itmp,jtmp,nI  ,nJ  ,1   ,iBLK)
        PlotVar(nI+1,0   ,nK+1,iVar)=ray(itmp,jtmp,nI  ,1   ,nK  ,iBLK)
        PlotVar(nI+1,nJ+1,nK+1,iVar)=ray(itmp,jtmp,nI  ,nJ  ,nK  ,iBLK)

        ! EXTRA RAYTRACE variables
     case('f1x')
        PlotVar(1:nI,1:nJ,1:nK,iVar)=rayface(1,1,1:nI,1:nJ,1:nK,iBLK)
     case('f1y')      	          		                   	   
        PlotVar(1:nI,1:nJ,1:nK,iVar)=rayface(2,1,1:nI,1:nJ,1:nK,iBLK)
     case('f1z')      	          		                   	   
        PlotVar(1:nI,1:nJ,1:nK,iVar)=rayface(3,1,1:nI,1:nJ,1:nK,iBLK)
     case('f2x')      	          		                   	   
        PlotVar(1:nI,1:nJ,1:nK,iVar)=rayface(1,2,1:nI,1:nJ,1:nK,iBLK)
     case('f2y')      	          		                   	   
        PlotVar(1:nI,1:nJ,1:nK,iVar)=rayface(2,2,1:nI,1:nJ,1:nK,iBLK)
     case('f2z')      	          		                   	   
        PlotVar(1:nI,1:nJ,1:nK,iVar)=rayface(3,2,1:nI,1:nJ,1:nK,iBLK)
!!$!^CFG END RAYTRACE

        ! GRID INFORMATION
     case('dx')
        PlotVar(:,:,:,iVar)=dx_BLK(iBLK)
     case('dt')
        PlotVar(1:nI,1:nJ,1:nK,iVar)=time_BLK(1:nI,1:nJ,1:nK,iBLK)
     case('dtblk')
        PlotVar(:,:,:,iVar)=dt_BLK(iBLK)
        if(.not.true_BLK(iBLK))then
           if(.not.any(true_cell(1:nI,1:nJ,1:nK,iBLK)))&
                PlotVar(:,:,:,iVar)=0.0
        end if
     case('cons')
        if(allocated(IsConserv_CB))then
           where(IsConserv_CB(:,:,:,iBLK))
              PlotVar(1:nI,1:nJ,1:nK,iVar)=1.
           elsewhere
              PlotVar(1:nI,1:nJ,1:nK,iVar)=0.
           end where
        else if(UseNonConservative)then
           PlotVar(1:nI,1:nJ,1:nK,iVar)=0.
        else
           PlotVar(1:nI,1:nJ,1:nK,iVar)=1.
        end if
     case('evolve','impl')
        PlotVar(:,:,:,iVar)=iTypeAdvance_B(iBLK)
        if(UsePointImplicit_B(iBLK))&
             PlotVar(:,:,:,iVar)=PlotVar(:,:,:,iVar)+0.5        
     case('proc')
        PlotVar(:,:,:,iVar)=iProc
     case('blk','block')
        PlotVar(:,:,:,iVar)=iBLK
     case('blkall')
        PlotVar(:,:,:,iVar)=global_block_number(iBLK)
     case('child')
        PlotVar(:,:,:,iVar)=BLKneighborCHILD(0,0,0,1,iBLK)
     case('hall')
        if(UseHallResist)then
           do k=1,nK; do j=1,nJ; do i=1,nI
              PlotVar(i,j,k,iVar) = hall_factor(0,i,j,k,iBlk)
           end do; end do; end do
        else
           PlotVar(:,:,:,iVar) = 0.0
        end if
     case default
        ! Check if the name is one of the state variable names
        do jVar = 1, nVar
           NameVar = NameVar_V(jVar)
           call lower_case(NameVar)
           if(NamePlotVar /= NameVar) CYCLE
           PlotVar(:,:,:,iVar) = State_VGB(jVar,:,:,:,iBLK)
           if(DefaultState_V(jVar) > cTiny) &
                plotvar_inBody(iVar) = CellState_VI(jVar,body1_)
           EXIT
        end do
        if(jVar > nVar) then
           call user_set_plot_var(iBLK, NamePlotVar, plot_dimensional(Plot_+iPlotFile), &
                PlotVar(:,:,:,iVar), &                
                plotvar_inBody(iVar), plotvar_useBody(iVar), &
                NameVarUserTec_I(iVar), NameUnitUserTec_I(iVar), &
                NameUnitUserIdl_I(iVar), IsFound)
           if(.not. IsFound) then
              PlotVar(:,:,:,iVar)=-7777.
              if(iProc==0.and.iBLK==1)write(*,*) &
                   'Warning in set_plotvar: unknown plotvarname=',&
                   plotvarnames(iVar),' for iplotfile=',iplotfile
           end if
        end if
     end select
  end do ! iVar
end subroutine set_plotvar

!==============================================================================
subroutine dimensionalize_plotvar(iBlk, iPlotFile, nPlotVar, plotvarnames, &
     plotvar, plotvar_inBody)

  use ModProcMH
  use ModMain, ONLY : nI, nJ, nK, BlkTest, ProcTest
  use ModPhysics
  use ModVarIndexes, ONLY: NameVar_V, UnitUser_V, DefaultState_V   
  use ModUtilities,  ONLY: lower_case
  use ModMultiFluid, ONLY: extract_fluid_name

  implicit none

  integer, intent(in) :: iBLK,iPlotFile,Nplotvar
  character (LEN=10), intent(in) :: plotvarnames(Nplotvar)
  real, intent(inout) :: plotVar(-1:nI+2,-1:nJ+2,-1:nK+2,nPlotVar)
  real, intent(inout) :: plotVar_inBody(nPlotVar)

  character (len=10)  :: String, NamePlotVar, NameVar

  integer :: iVar, i,j,k, jVar
  logical :: DoTest,DoTestMe
  !---------------------------------------------------------------------------
  if(iBLK==BlkTest.and.iProc==ProcTest)then
     call set_oktest('dimensionalize_plotvar',DoTest,DoTestMe)
  else
     DoTest=.false.; DoTestMe=.false.
  end if

  do iVar=1,nPlotVar
     NamePlotVar = plotvarnames(iVar)
     call lower_case(NamePlotVar)
     String = NamePlotVar
     call extract_fluid_name(String)

     ! Set plotvar_inBody to something reasonable for inside the body.
     ! Load zeros (0) for most values - load something better for rho, p, and T
     ! We know that U,B,J are okay with zeroes, others should be changed if
     ! necessary.  
     ! Note that all variables not set to 0 in set_plotvar should be 
     ! loaded below. Note that this is used for tecplot corner extrapolation 
     ! and for nothing else.

     select case(String)

        ! BASIC MHD variables

     case('rho')
        PlotVar(:,:,:,iVar)=PlotVar(:,:,:,iVar)*No2Io_V(UnitRho_)
        plotvar_inBody(iVar)=plotvar_inBody(iVar)*No2Io_V(UnitRho_)
     case('rhoux','mx','rhouy','my','rhouz','mz','rhour','mr' )
        PlotVar(:,:,:,iVar)=PlotVar(:,:,:,iVar)*No2Io_V(UnitRhoU_)
     case('bx','by','bz','br','b1x','b1y','b1z','b1r' &
          ,'bxl','bxr','byl','byr','bzl','bzr' &         !^CFG IF CONSTRAINB
          )
        PlotVar(:,:,:,iVar)=PlotVar(:,:,:,iVar)*No2Io_V(UnitB_)
     case('e','e1')
        PlotVar(:,:,:,iVar)=PlotVar(:,:,:,iVar)*No2Io_V(UnitEnergyDens_)
     case('p','pth')
        PlotVar(:,:,:,iVar)=PlotVar(:,:,:,iVar)*No2Io_V(UnitP_)
        plotvar_inBody(iVar)=plotvar_inBody(iVar)*No2Io_V(UnitP_)

        ! EXTRA MHD variables
     case('n')
        PlotVar(:,:,:,iVar)=PlotVar(:,:,:,iVar)*No2Io_V(UnitN_)
     case('t','temp')
        PlotVar(:,:,:,iVar)=PlotVar(:,:,:,iVar)*No2Io_V(UnitTemperature_)
     case('ux','uy','uz')
        PlotVar(:,:,:,iVar)=PlotVar(:,:,:,iVar)*No2Io_V(UnitU_)
     case('jx','jy','jz','jr',&
          'jxe','jye','jze','jxw','jyw','jzw', &
          'jxs','jys','jzs','jxn','jyn','jzn', &
          'jxb','jyb','jzb','jxt','jyt','jzt')
        PlotVar(:,:,:,iVar)=PlotVar(:,:,:,iVar)*No2Io_V(UnitJ_)
     case('ex','ey','ez','er','enumx','enumy','enumz')
        PlotVar(:,:,:,iVar)=PlotVar(:,:,:,iVar)*No2Io_V(UnitElectric_)
     case('pvecx','pvecy','pvecz','pvecr','b2ur')
        PlotVar(:,:,:,iVar)=PlotVar(:,:,:,iVar)*No2Io_V(UnitPoynting_)
     case('divb','divb_cd','divb_ct','absdivb')
        PlotVar(:,:,:,iVar)=PlotVar(:,:,:,iVar)*No2Io_V(UnitDivB_)

        ! GRID INFORMATION
     case('dt','dtblk')
        PlotVar(:,:,:,iVar)=PlotVar(:,:,:,iVar)*No2Io_V(UnitT_)
     case('dx')
        PlotVar(:,:,:,iVar)=PlotVar(:,:,:,iVar)*No2Io_V(UnitX_)

        ! DEFAULT CASE
     case default
        do jVar = 1, nVar
           NameVar = NameVar_V(jVar)
           call lower_case(NameVar)
           if(NamePlotVar /= NameVar) CYCLE
           PlotVar(:,:,:,iVar)=PlotVar(:,:,:,iVar)*UnitUser_V(jVar)
           if(DefaultState_V(jVar)>cTiny)&
                plotvar_inBody(iVar)=plotvar_inBody(iVar)*UnitUser_V(jVar)
           EXIT
        end do
        ! no normalization
     end select
  end do ! iVar
end subroutine dimensionalize_plotvar

!==============================================================================

subroutine get_tec_variables(iFile, nPlotVar, NamePlotVar_V, StringVarTec)

  use ModPhysics
  use ModUtilities,  ONLY: lower_case
  use ModIO,         ONLY: plot_type,plot_dimensional
  use ModVarIndexes, ONLY: NameVar_V, NameUnitUserTec_V
  use ModIO,         ONLY: NameVarUserTec_I, NameUnitUserTec_I
  use ModMultiFluid, ONLY: extract_fluid_name, iFluid, NameFluid

  implicit none

  ! Arguments

  integer, intent(in)              :: nPlotVar, iFile
  character (len=10), intent(in)   :: NamePlotVar_V(nPlotVar)
  character (len=500), intent(out) :: StringVarTec 

  character (len=20) :: NameTecFluid
  character (len=10) :: String, NamePlotVar, NameVar, NameTecVar, NameUnit
  integer            :: iPlotVar, iVar, i
  !---------------------------------------------------------------------------
  !\
  ! This routine takes the plot_var information and loads the header file with
  ! the appropriate string of variable names and units
  !/

  ! Coordinate names and units
  if(index(plot_type(ifile),'sph')>0) then

     if (plot_dimensional(ifile)) then
        StringVarTec = 'VARIABLES ="X ' // trim(NameTecUnit_V(UnitX_)) &
             // '", "Y ' // trim(NameTecUnit_V(UnitX_)) &
             // '", "Z ' // trim(NameTecUnit_V(UnitX_)) &
             // '", "`q [degree]", "`f[degree]'
     else
   	StringVarTec = 'VARIABLES = "X", "Y", "Z", "`q", "`f'
     end if

  else

     if (plot_dimensional(ifile)) then
        StringVarTec = 'VARIABLES ="X ' // trim(NameTecUnit_V(UnitX_)) &
             // '", "Y ' // trim(NameTecUnit_V(UnitX_)) &
             // '", "Z ' // trim(NameTecUnit_V(UnitX_))
     else
   	StringVarTec = 'VARIABLES = "X", "Y", "Z'
     end if

  end if

  do iPlotVar = 1, nPlotVar

     NamePlotVar = NamePlotVar_V(iPlotVar)
     call lower_case(NamePlotVar)
     String = NamePlotVar
     call extract_fluid_name(String)
     if(iFluid == 1)then
        NameTecFluid = ''
     else
        do i = 1, len_trim(NameFluid)
           NameTecFluid(2*i-1:2*i) = '^'//NameFluid(i:i)
        end do
     end if

     ! Default value for NameUnit is empty string
     NameUnit = ''

     select case(String)
     case('rho') 
        NameTecVar = '`r'//NameTecFluid
        NameUnit   = NameTecUnit_V(UnitRho_)
     case('rhoux','mx') 
        NameTecVar = '`r U_x'//NameTecFluid
        NameUnit   = NameTecUnit_V(UnitRhoU_)
     case('rhouy','my') 
        NameTecVar = '`r U_y'//NameTecFluid
        NameUnit   = NameTecUnit_V(UnitRhoU_)
     case('rhouz','mz') 
        NameTecVar = '`r U_z'//NameTecFluid
        NameUnit   = NameTecUnit_V(UnitRhoU_)
     case('bx') 
        NameTecVar = 'B_x'
        NameUnit   = NameTecUnit_V(UnitB_)
     case('by') 
        NameTecVar = 'B_y'
        NameUnit   = NameTecUnit_V(UnitB_)
     case('bz') 
        NameTecVar = 'B_z'
        NameUnit   = NameTecUnit_V(UnitB_)
        ! face centered magnetic field       !^CFG IF CONSTRAINB BEGIN
     case('bxl') ! east
        NameTecVar = 'B_e'
        NameUnit   = NameTecUnit_V(UnitB_)
     case('bxr') ! west
        NameTecVar = 'B_w'
        NameUnit   = NameTecUnit_V(UnitB_)
     case('byl') ! south
        NameTecVar = 'B_s'
        NameUnit   = NameTecUnit_V(UnitB_)
     case('byr') ! north
        NameTecVar = 'B_n'
        NameUnit   = NameTecUnit_V(UnitB_)
     case('bzl') ! bottom
        NameTecVar = 'B_b'
        NameUnit   = NameTecUnit_V(UnitB_)
     case('bzr') ! top
        NameTecVar = 'B_t'
        NameUnit   = NameTecUnit_V(UnitB_)
        !                                        !^CFG END CONSTRAINB
     case('e')
        NameTecVar = 'E'//NameTecFluid
        NameUnit   = NameTecUnit_V(UnitEnergydens_)
     case('p','pth')
        NameTecVar = 'p'//NameTecFluid
        NameUnit   = NameTecUnit_V(UnitP_)
     case('n')
        NameTecVar = 'n'//NameTecFluid
        NameUnit   = NameTecUnit_V(UnitN_)
     case('t','temp')
        NameTecVar = 'T'//NameTecFluid
        NameUnit   = NameTecUnit_V(UnitTemperature_)
     case('ux') 
        NameTecVar = 'U_x'//NameTecFluid
        NameUnit   = NameTecUnit_V(UnitU_)
     case('uy') 
        NameTecVar = 'U_y'//NameTecFluid
        NameUnit   = NameTecUnit_V(UnitU_)
     case('uz') 
        NameTecVar = 'U_z'//NameTecFluid
        NameUnit   = NameTecUnit_V(UnitU_)
     case('ur') 
        NameTecVar = 'U_r'//NameTecFluid
        NameUnit   = NameTecUnit_V(UnitU_)
     case('rhour','mr') 
        NameTecVar = '`r U_r'//NameTecFluid
        NameUnit   = NameTecUnit_V(UnitRhoU_)
     case('br') 
        NameTecVar = 'B_r'
        NameUnit   = NameTecUnit_V(UnitB_)
     case('b1x') 
        NameTecVar = 'B1_x'
        NameUnit   = NameTecUnit_V(UnitB_)
     case('b1y')                                 
        NameTecVar = 'B1_y'
        NameUnit   = NameTecUnit_V(UnitB_)
     case('b1z')                                 
        NameTecVar = 'B1_z'
        NameUnit   = NameTecUnit_V(UnitB_)
     case('b1r')                                 
        NameTecVar = 'B1_r'
        NameUnit   = NameTecUnit_V(UnitB_)
     case('jx') 
        NameTecVar = 'J_x'
        NameUnit   = NameTecUnit_V(UnitJ_)
     case('jy')                                 
        NameTecVar = 'J_y'
        NameUnit   = NameTecUnit_V(UnitJ_)
     case('jz')                                 
        NameTecVar = 'J_z'
        NameUnit   = NameTecUnit_V(UnitJ_)
     case('jr')                                 
        NameTecVar = 'J_r'
        NameUnit   = NameTecUnit_V(UnitJ_)
     case('ex')
        NameTecVar = 'E_x'
        NameUnit   = NameTecUnit_V(UnitElectric_)
     case('ey')
        NameTecVar = 'E_y'
        NameUnit   = NameTecUnit_V(UnitElectric_)
     case('ez')                                 
        NameTecVar = 'E_z'
        NameUnit   = NameTecUnit_V(UnitElectric_)
     case('er')                                 
        NameTecVar = 'E_r'
        NameUnit   = NameTecUnit_V(UnitElectric_)
     case('pvecx')
        NameTecVar = 'S_x'
        NameUnit   = NameTecUnit_V(UnitPoynting_)
     case('pvecy')
        NameTecVar = 'S_y'
        NameUnit   = NameTecUnit_V(UnitPoynting_)              
     case('pvecz')
        NameTecVar = 'S_z'
        NameUnit   = NameTecUnit_V(UnitPoynting_)              
     case('pvecr')
        NameTecVar = 'S_r'
        NameUnit   = NameTecUnit_V(UnitPoynting_)
     case('b2ur')
        NameTecVar = 'B^2/`u_0 U_r'
        NameUnit   = NameTecUnit_V(UnitPoynting_)                
     case('divb', 'divb_cd', 'divb_ct', 'absdivb')
        NameTecVar = '~Q~7B'
        NameUnit   = NameTecUnit_V(UnitDivB_)
     case('theta1')                              !^CFG  IF RAYTRACE BEGIN
        NameTecVar = '`q_1'
        NameUnit   = NameTecUnit_V(UnitAngle_)
     case('phi1')
        NameTecVar = '`f_1'
        NameUnit   = NameTecUnit_V(UnitAngle_)
     case('theta2')
        NameTecVar = '`q_2'
        NameUnit   = NameTecUnit_V(UnitAngle_)
     case('phi2')
        NameTecVar = '`f_2'
        NameUnit   = NameTecUnit_V(UnitAngle_)
     case('status')
        NameTecVar = 'Status'
     case('f1x','f1y','f1z','f2x','f2y','f2z')
        NameTecVar = NamePlotVar                 !^CFG END RAYTRACE
     case('dx')
        NameTecVar = 'dx'
        NameUnit   = NameTecUnit_V(UnitX_)
     case('dt')
        NameTecVar = 'dt'
        NameUnit   = NameTecUnit_V(UnitT_)
     case('dtblk')
        NameTecVar = 'dtblk'
        NameUnit   = NameTecUnit_V(UnitT_)
     case('impl')                                !^CFG IF IMPLICIT
        NameTecVar = 'impl'                      !^CFG IF IMPLICIT
     case('proc')
        NameTecVar = 'PE #'
     case('blk')
        NameTecVar = 'Block #'
     case('blkall')
        NameTecVar = 'blkall'
     case('child')
        NameTecVar = 'Child #'
     case default
        ! Set the default or user defined values
        NameTecVar = NameVarUserTec_I(iPlotVar)
        NameUnit   = NameUnitUserTec_I(iPlotVar)

        ! Try to find the plot variable among the basic variables
        do iVar = 1, nVar
           NameVar = NameVar_V(iVar)
           call lower_case(NameVar)
           if(NameVar == NamePlotVar)then
              NameUnit = NameUnitUserTec_V(iVar)
              EXIT
           end if
        end do
     end select

     StringVarTec = trim(StringVarTec) // '", "' // NameTecVar

     if (plot_dimensional(ifile)) &
          StringVarTec = trim(StringVarTec) // ' ' //NameUnit

  end do

  ! Append a closing double quote
  StringVarTec = trim(StringVarTec) // '"'

end subroutine get_TEC_variables

!==============================================================================

subroutine get_idl_units(iFile, nPlotVar, NamePlotVar_V, StringUnitIdl)

  use ModPhysics
  use ModUtilities,  ONLY: lower_case
  use ModIO,         ONLY: plot_type, plot_dimensional, NameUnitUserIdl_I
  use ModVarIndexes, ONLY: NameVar_V, NameUnitUserIdl_V
  use ModMultiFluid, ONLY: extract_fluid_name
  implicit none

  ! Arguments

  integer, intent(in)             :: iFile, nPlotVar
  character (len=10), intent(in)  :: NamePlotVar_V(nPlotVar)
  character (len=500),intent(out) :: StringUnitIdl 

  character (len=10) :: String, NamePlotVar, NameVar, NameUnit
  integer            :: iPlotVar, iVar

  !\
  ! This routine takes the plot_var information and loads the header file with
  ! the appropriate string of unit values
  !/

  if(.not.plot_dimensional(iFile))then
     StringUnitIdl = 'normalized variables'
     RETURN
  end if

  if(index(plot_type(ifile),'sph')>0) then
     StringUnitIdl = trim(NameIdlUnit_V(UnitX_))//' deg deg'
  else
     StringUnitIdl = trim(NameIdlUnit_V(UnitX_))//' '//&
          trim(NameIdlUnit_V(UnitX_))//' '//trim(NameIdlUnit_V(UnitX_))
  end if

  do iPlotVar = 1, nPlotVar

     NamePlotVar = NamePlotVar_V(iPlotVar)
     call lower_case(NamePlotVar)
     String = NamePlotVar
     call extract_fluid_name(String)

     select case(String)
     case('rho') 
        NameUnit = NameIdlUnit_V(UnitRho_)
     case('rhoux','mx','rhouy','rhoUz','rhouz','mz','rhour','mr')
        NameUnit = NameIdlUnit_V(UnitRhoU_)
     case('bx','by','bz','b1x','b1y','b1z','br','b1r')
        NameUnit = NameIdlUnit_V(UnitB_)
     case('e')
        NameUnit = NameIdlUnit_V(UnitEnergydens_)
     case('p','pth')
        NameUnit = NameIdlUnit_V(UnitP_)
     case('n')
        NameUnit = NameIdlUnit_V(UnitN_)
     case('t','temp')
        NameUnit = NameIdlUnit_V(UnitTemperature_)
     case('ux','uy','uz','ur')
        NameUnit = NameIdlUnit_V(UnitU_)
     case('jx','jy','jz','jr',&
          'jxe','jye','jze','jxw','jyw','jzw', &
          'jxs','jys','jzs','jxn','jyn','jzn', &
          'jxb','jyb','jzb','jxt','jyt','jzt')
        NameUnit = NameIdlUnit_V(UnitJ_)
     case('ex','ey','ez','er','enumx','enumy','enumz')
        NameUnit = NameIdlUnit_V(UnitElectric_)
     case('pvecx','pvecy','pvecz','pvecr','b2ur')
        NameUnit = NameIdlUnit_V(UnitPoynting_)
     case('divb','divb_cd','divb_ct','absdivb')
        NameUnit = NameIdlUnit_V(UnitDivB_)
     case('theta1','phi1','theta2','phi2')       !^CFG  IF RAYTRACE BEGIN
        NameUnit = NameIdlUnit_V(UnitAngle_)
     case('status','f1x','f1y','f1z','f2x','f2y','f2z')
        NameUnit = '--'                          !^CFG END RAYTRACE
        ! GRID INFORMATION
     case('proc','blk','blkall','child','impl','evolve')
        NameUnit = '1'
     case('dt', 'dtblk')
        NameUnit = NameIdlUnit_V(UnitT_)
     case('dx')
        NameUnit = NameIdlUnit_V(UnitX_)
     case default
        ! Set default or user defined unit
        NameUnit = NameUnitUserIdl_I(iPlotVar)

        ! Try to find the plot variable among the basic variables
        do iVar = 1, nVar
           NameVar = NameVar_V(iVar)
           call lower_case(NameVar)
           if(NameVar == NamePlotVar)then
              NameUnit = NameUnitUserIdl_V(iVar)
              EXIT
           end if
        end do
     end select
     ! Append the unit string for this variable to the output string
     StringUnitIdl = trim(StringUnitIdl)//' '//trim(NameUnit)
  end do

end subroutine get_idl_units
