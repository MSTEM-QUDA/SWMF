!  Copyright (C) 2002 Regents of the University of Michigan, 
!  portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
!==============================================================================

subroutine write_progress(inopt)
  use ModProcMH
  use ModMain
  use ModIO, ONLY: iUnitOut, write_prefix
  use ModUser, ONLY: NameUserModule, VersionUserModule
  use ModVarIndexes, ONLY: NameEquation
  implicit none

  integer, intent(in) :: inopt
  !----------------------------------------------------------------------------

  if (iProc /= 0 .or. lVerbose<=0) return

  select case(inopt)
  case (0)
     write(iUnitOut,*)
     call write_prefix; write(iUnitOut,'(a)') &
          " BATSRUS: Block Adaptive Tree Solar-Wind Roe Upwind Scheme"
     call write_prefix; write(iUnitOut,'(a)') &
          "          for 3D Heliospheric Flows"
     call write_prefix; write(iUnitOut,'(a)') &
          " University of Michigan, 1995-2007"
     write(iUnitOut,*)
     if(IsStandAlone)then
        call write_prefix; write(iUnitOut,'(a,f4.2,a,i6,a)') &
             ' BATSRUS version ',CodeVersion,&
             ' is running as '//NameThisComp//' on ',nProc,' PE(s)'
        write(iUnitOut,*)
     end if
     call write_prefix; write(iUnitOut,'(a)') &
          ' EQUATIONS:   '//NameEquation
     call write_prefix; write(iUnitOut,'(a,f5.2)') &
          ' USER MODULE: '//NameUserModule,VersionUserModule
     write(iUnitOut,*)
  case (1)
     call write_prefix; write(iUnitOut,*)
     call write_prefix
     if (time_accurate) then
        write(iUnitOut,*) 'Restarted run from N = ',n_step,' steps ', &
             'and T = ',Time_Simulation, &
             ' (',Time_Simulation/60.00, &
             ' min, ',Time_Simulation/3600.00,' hrs).'
     else
        write(iUnitOut,*) 'Restarted run from N = ',n_step,' steps.'
     end if
  end select
end subroutine write_progress

!==============================================================================

subroutine write_runtime_values()

  use ModMain
  use ModPhysics
  use ModIO,        ONLY: iUnitOut, write_prefix
  use ModProcMH,    ONLY: iProc, nProc, iComm
  use ModFaceValue, ONLY: TypeLimiter, BetaLimiter
  use ModAdvance,   ONLY: FluxType
  use ModGeometry,  ONLY: x1,x2,y1,y2,z1,z2,minDXvalue,maxDXvalue
  use ModParallel,  ONLY: proc_dims
  use ModImplicit,  ONLY: UseImplicit, UseSemiImplicit, UseSplitSemiImplicit, &
       TypeSemiImplicit
  use ModMultiFluid, ONLY: IonFirst_, UseNeutralFluid, iFluid
  use ModFaceFlux,   ONLY: TypeFluxNeutral
  use CON_planet,   ONLY: NamePlanet, IsPlanetModified, Planet_, NewPlanet_, &
       RadiusPlanet, MassPlanet, TiltRotation, OmegaPlanet, OmegaOrbit, &
       IonosphereHeight
  use ModMpi
  use ModUserInterface ! user_action

  implicit none

  character(len=100):: String, StringFormat
  integer           :: iError
  real              :: DxMin, DxMax    
  !------------------------------------------------------------------------

  ! Find new min and max dx
  call count_true_cells

  if (iProc /= 0 .or. lVerbose<=0) RETURN

  call write_prefix; write(iUnitOut,*)
  call write_prefix; write(iUnitOut,*)'   Begin Numerical Simulation'
  call write_prefix; write(iUnitOut,*)'   --------------------------'
  call write_prefix; write(iUnitOut,*)
  call write_prefix; write(iUnitOut,*)
  if (NamePlanet /= 'NONE' .and. body1 .and. NameThisComp == 'GM') then
     call write_prefix; write(iUnitOut,*)'   Planetary Parameters'
     call write_prefix; write(iUnitOut,*)'   --------------------'
     call write_prefix; write(iUnitOut,*)
     String = ''
     if (IsPlanetModified .and. (Planet_ /= NewPlanet_)) &
          String = '( default values were modified! )'
     call write_prefix; write(iUnitOUT,'(10X,A,A,2x,A)')  &
          'Name:           ', trim(NamePlanet), trim(String)
     StringFormat = '(10X,A16,ES13.5)'
     call write_prefix; write(iUnitOUT,StringFormat) &
          'Radius:         ', RadiusPlanet
     call write_prefix; write(iUnitOUT,StringFormat) &
          'Mass:           ', MassPlanet
     String = ' Not Rotating'
     if (OmegaPlanet /= 0.0) write(String, '(ES13.5)') cTwoPi/OmegaPlanet
     call write_prefix; write(iUnitOUT,'(10X,A,A)')'Rotation Period:', &
          trim(String)
     call write_prefix; write(iUnitOUT,StringFormat) &
          'Rot. Tilt [deg]:', TiltRotation*cRadToDeg
     String = ' Not Orbiting'
     if (OmegaOrbit /= 0.0) write(String, '(ES13.5)') cTwoPi/OmegaOrbit
     call write_prefix; write(iUnitOUT,'(10X,A,A)')'Orbit Period:   ', &
          trim(String)
     call write_prefix; write(iUnitOUT,StringFormat) &
          'Iono Height:    ', IonosphereHeight
     call write_prefix; write(iUnitOut,*)
  end if
  call write_prefix; write(iUnitOut,*) '   Physical Parameters'
  call write_prefix; write(iUnitOut,*) '   -------------------'
  call write_prefix; write(iUnitOut,*)
  call write_prefix; write(iUnitOUT,'(10X,a)') &
       'I/O Unit type: '//trim(TypeIoUnit)//'            '// &
       'Normalization: '//trim(TypeNormalization)
  call write_prefix; write(iUnitOut,*)
  call write_prefix; write(iUnitOut,'(10X,a,f12.8)') 'Gamma:       ',g
  call write_prefix; write(iUnitOut,*)
  if(body1)then
     call write_prefix; write(iUnitOut,'(10X,2(A13,ES13.5))') &
          'rBody:       ', rBody,      ', rPlanet:   ',rPlanetSi
     do iFluid = IonFirst_, nFluid
        call write_prefix; write(iUnitOut,'(10X,2(A13,ES13.5))') &
             'BodyNDim:    ',BodyNDim_I(iFluid), &
             ', BodyTDim:  ',BodyTDim_I(iFluid)
     end do
     call write_prefix; write(iUnitOut,'(10X,2(A13,ES13.5))') &
          'Bdp:         ',Bdp      ,', Tilt [deg]:',ThetaTilt*cRadToDeg
     if(UseRotatingBc)then
        call write_prefix; write(iUnitOut,'(10X,a)') 'Corotation is used'
     end if
  else
     call write_prefix; write(iUnitOut,'(10X,''UseBody1: .false.'')')
  end if
  if(UseGravity)then
     call write_prefix; write(iUnitOut,'(10X,a,ES13.5)') &
          'Gravity is used, gBody=', gBody
  end if
  call write_prefix; write(iUnitOut,*)

  if (UseBody2) then
     call write_prefix
     write(iUnitOut,'(10X,''UseBody2: .true.'')')
     call write_prefix; write(iUnitOut,'(10X,2(A13,ES13.5))') &
          'rBody2:      ',RBody2   ,', BdpDimBody2: ',&
          sqrt(sum(BdpDimBody2_D**2))
     call write_prefix; write(iUnitOut,'(10X,2(A13,ES13.5))') &
          'xBody2:      ',xBody2   ,', Bdp2Body_x:    ',BdpBody2_D(1)
     call write_prefix; write(iUnitOut,'(10X,2(A13,ES13.5))') &
          'yBody2:      ',yBody2   ,', Bdp2Body_y:    ',BdpBody2_D(2)
     call write_prefix; write(iUnitOut,'(10X,2(A13,ES13.5))') &
          'zBody2:      ',zBody2   ,', Bdp2Body_z:    ',BdpBody2_D(3)
     call write_prefix
     write(iUnitOut,'(10X,2(A13,ES13.5))') &
          'RhoDimBody2: ',RhoDimBody2,', TDimBody2:   ',TDimBody2
     if (UseBody2Orbit) then
        call write_prefix; write(iUnitOut,'(10X,''UseBody2Orbit: .true.'')')
        call write_prefix; write(iUnitOut,'(10X,2(A13,ES13.5))') &
             'OrbitPeriod: ', OrbitPeriod/cSecondPerDay 
     endif
  else
     call write_prefix
     write(iUnitOut,'(10X,''UseBody2: .false.'')')
  end if


  call write_prefix; write(iUnitOut,*)
  call write_prefix; write(iUnitOut,'(10X,2(A13,ES13.5))')&
       'ClightFactor:',boris_clight_factor,', Clight:    ',Clight
  call write_prefix; write(iUnitOut,*)

  if(NameThisComp == 'GM' .and. SW_n > 0.0)then
     call write_prefix; write(iUnitOut,*)
     StringFormat = '(10X,A17,"]: ",F15.6,A10,F15.6)'
     call write_prefix; write(iUnitOut,StringFormat) &
          'SW_n_dim   ['//NameIdlUnit_V(UnitN_),SW_n_dim,  ',  SW_n:  ',SW_n
     call write_prefix; write(iUnitOut,StringFormat) &
          'SW_Rho_dim ['//NameIdlUnit_V(UnitRho_),SW_Rho_dim,',  SW_Rho:',&
          SW_Rho
     call write_prefix; write(iUnitOut,StringFormat) &
          'SW_Ux_dim  ['//NameIdlUnit_V(UnitU_),SW_Ux_dim, ',  SW_Ux: ',SW_Ux
     call write_prefix; write(iUnitOut,StringFormat) &
          'SW_Uy_dim  ['//NameIdlUnit_V(UnitU_),SW_Uy_dim, ',  SW_Uy: ',SW_Uy
     call write_prefix; write(iUnitOut,StringFormat) &
          'SW_Uz_dim  ['//NameIdlUnit_V(UnitU_),SW_Uz_dim, ',  SW_Uz: ',SW_Uz
     call write_prefix; write(iUnitOut,StringFormat) &
          'SW_p_dim   ['//NameIdlUnit_V(UnitP_),SW_p_dim,  ',  SW_p:  ',SW_p
     call write_prefix; write(iUnitOut,StringFormat) &
          'SW_Bx_dim  ['//NameIdlUnit_V(UnitB_),SW_Bx_dim, ',  SW_Bx: ',SW_Bx
     call write_prefix; write(iUnitOut,StringFormat) &
          'SW_By_dim  ['//NameIdlUnit_V(UnitB_),SW_By_dim, ',  SW_By: ',SW_By
     call write_prefix; write(iUnitOut,StringFormat) &
          'SW_Bz_dim  ['//NameIdlUnit_V(UnitB_),SW_Bz_dim, ',  SW_Bz: ',SW_Bz
     StringFormat = '(10X,A17,"]: ",F15.6)'
     call write_prefix; write(iUnitOut,StringFormat) &
          'SW_T_dim   ['//NameIdlUnit_V(UnitTemperature_),SW_T_dim
  end if
  call write_prefix; write(iUnitOut,*)
  call write_prefix; write(iUnitOut,*)'   MHD Numerical Solution Parameters'
  call write_prefix; write(iUnitOut,*)'   ---------------------------------'
  call write_prefix; write(iUnitOut,*)

  call write_prefix
  select case (nOrder)
  case (1)
     write(iUnitOut,'(10X,a)') '1st-order scheme'
  case (2)
     write(iUnitOut,'(10X,a)') '2nd-order scheme with '//trim(TypeLimiter)// &
          ' limiter'
  case (4)
     write(iUnitOut,'(10X,a)') '4th-order scheme with '//trim(TypeLimiter)// &
          ' limiter'
  case (5)
     write(iUnitOut,'(10X,a)') '5th-order scheme with '//trim(TypeLimiter)// &
          ' limiter'
  end select
  if(nOrder > 1 .and. TypeLimiter /= 'minmod') then
     call write_prefix;
     write(iUnitOut,'(10x,a,f5.2)') '    BetaLimiter =', BetaLimiter
  end if

  call write_prefix
  write(iUnitOut,'(10X,a,a)') trim(FluxType),' flux function'
  if(UseNeutralFluid)then
     call write_prefix
     write(iUnitOut,'(10X,a,a)') trim(TypeFluxNeutral), &
          ' flux for neutral fluids'
  end if

  call write_prefix
  if (time_accurate) then
     write(iUnitOut,'(10X,a)') 'Time accurate calculation'
  else
     write(iUnitOut,'(10X,a)') 'Steady state calculation'
  end if

  call write_prefix
  if (UseImplicit) then
     write(iUnitOut,'(10X,a)') 'Implicit time stepping'
  elseif(UseSemiImplicit)then
     if(UseSplitSemiImplicit)then
        write(iUnitOut,'(10X,a)') 'Split semi-implicit time stepping for '// &
             trim(TypeSemiImplicit)
     else
        write(iUnitOut,'(10X,a)') 'Semi-implicit time stepping for '// &
             trim(TypeSemiImplicit)
     end if
  else
     write(iUnitOut,'(10X,a)') 'Explicit time stepping'
  end if

  call write_prefix; write(iUnitOut,'(10x,a,i1)')   '    nStage: ', nStage
  call write_prefix
  if(UseDtFixed)then
     write(iUnitOut,*) '             Dt:    ', Dt
  else
     write(iUnitOut,'(10x,a,f4.2)') '    Cfl:    ', Cfl
  end if
  if(boris_correction)then
     call write_prefix     
     write(iUnitOut,'(10X,a,f10.4)') &
          "    with Boris correction, factor =", boris_cLIGHT_factor
  end if
  if(UseBorisSimple)then
     call write_prefix
     write(iUnitOut,'(10X,a,f10.4)') &
          "   with simple Boris correction, factor =", boris_cLIGHT_factor
  end if

  call write_prefix; write(iUnitOut,*)
  call write_prefix; write(iUnitOut,*)'   Other Runtime Parameters'
  call write_prefix; write(iUnitOut,*)'   ------------------------'
  call write_prefix; write(iUnitOut,*)
  call write_prefix; write(iUnitOut,*)'Available processors: nProc = ',nProc
  call write_prefix; write(iUnitOut,*)
  call write_prefix; write(iUnitOut,*)'After initial grid setup:'
  call write_prefix; write(iUnitOut,*)'  nBlockMax = ',nBlockMax, &
       ' nBLK = ',nBLK
  call write_prefix; write(iUnitOut,*)'  Total number of blocks used = ', &
       nBlockALL
  call write_prefix; write(iUnitOut,*)'  Total number of cells = ', &
       nBlockALL*nIJK
  call write_prefix; write(iUnitOut,*)'  Total number of true cells = ', &
       nTrueCellsALL
  call write_prefix; write(iUnitOut,*)'  Smallest cell dx: ', minDXvalue, &
       '  Largest cell dx: ', maxDXvalue

  ! Constrained transport is not implemented for AMR grids anymore...
  if(UseConstrainB .and.  minDXvalue /= maxDXvalue) &
       call stop_mpi('Constrained transport works on uniform grid only!')

  call write_prefix; write(iUnitOut,*)
  call write_prefix
  write(iUnitOut,'(1x,a,3i8)')    'root blocks: ', proc_dims
  call write_prefix
  write(iUnitOut,'(1x,a,3i8)')    'nIJK_D:      ', nIJK_D
  call write_prefix
  write(iUnitOut,'(1x,a,2f16.8)') 'x:           ', x1, x2
  call write_prefix
  write(iUnitOut,'(1x,a,2f16.8)') 'y:           ', y1, y2
  call write_prefix
  write(iUnitOut,'(1x,a,2f16.8)') 'z:           ', z1, z2
  call write_prefix; write(iUnitOut,*)
  if(UseUserEchoInput) call user_action('write progress')

end subroutine write_runtime_values

!==============================================================================

subroutine write_timeaccurate

  use ModMain, ONLY : Time_Simulation
  implicit none

  write(*, '(a,e13.5,a,f12.6,a,f12.6,a)') &
       '   Simulated Time T = ',Time_Simulation, &
       ' (',Time_Simulation/60.00, &
       ' min, ',Time_Simulation/3600.00,' hrs)'

end subroutine write_timeaccurate

!============================================================================

subroutine count_true_cells
  use ModMain
  use ModProcMH
  use ModMpi
  use ModGeometry, ONLY : true_cell

  integer :: iBlk, i,j,k, iError
  !----------------------------------------------------------------------------

  nTrueCells=0
  do iBlk=1,nBlockMax  ! Block loop
     if(Unused_B(iBlk))CYCLE
     do k=1,nK; do j=1,nJ; do i=1,nI  ! Cell loop
        if(true_cell(i,j,k,iBlk)) nTrueCells=nTrueCells+1
     end do; end do; end do
  end do
  call MPI_reduce(nTrueCells,nTrueCellsALL,1,MPI_INTEGER,MPI_SUM,0,iComm,iError)

end subroutine count_true_cells
