module ModWaves

  use ModAdvance,    Only: UseWavePressure
  use ModPhysics,    ONLY: GammaWave
  use ModVarIndexes, ONLY: nWave, WaveFirst_, WaveLast_
  use ModSize,       ONLY: nI, nJ, nK

  implicit none

  logical:: DoAdvectWaves = .true.

  !
  ! Intended to simulate waves and wave turbulences. The wave propagate
  ! with respect to the background with some speed. The only implemented
  ! case is the propagation with Alfven speed, \pm V_A=\sqrt{B^2/rho}

  logical:: UseAlfvenWaves = .false.

  integer, private, parameter :: nWaveHalf = max(nWave/2, 1)

  integer, parameter :: AlfvenWavePlusFirst_ = WaveFirst_
  integer, parameter :: AlfvenWavePlusLast_  = WaveFirst_ - 1 + nWaveHalf

  integer, parameter :: AlfvenWaveMinusFirst_ = WaveLast_ + 1 - nWaveHalf
  integer, parameter :: AlfvenWaveMinusLast_  = WaveLast_


  real :: AlfvenSpeed  !Auxiliary variable

  real :: FreqMinSI = -1.0
  real :: FreqMaxSI = -1.0

  ! Centered frequency, for each bin
  ! The logarithmic grid is set by default. 
  ! Can be reset in use_user_perturbation

  real, dimension(WaveFirst_:WaveLast_):: FrequencySi_W = -1.0


  real :: DeltaLogFrequency = 0.0

  !To switch this option, set UseAlfvenWaves = .true.  
  !and modify accordingly the named indexes to set the state variables for
  !which the advection with \pm V_A should be applied

  !The background affects the wave propagation and, accordingly, the wave
  !should affect the background motion. The only case is implemented:
  !wave contribute to the total pressure, the contribution being equal
  !to (gamma_W-1)\sum{state vector components assigned to the waves}
  !This assumes a proper normalization of the wave state variables
  !(they should have a sense of the wave energy, should be multiplied if
  !needed by \omega, \Delta \log \omega etc (Rona's {\cal I} is an example).

  !Again, the wave pressure logicals and named indexes should be modified
  !only via the user routines.

  !For multi-component wave pressure the limitatation of different
  !frequency groups does not ensure the proper limitation of the total 
  !pressure therefore, it is reasonble to collect the total wave pressure
  !and limit it accordingly 
  logical:: UseWavePressureLtd = .false.

  !Spectral functions: all functions are normalized by unity

  real,dimension(WaveFirst_:WaveLast_):: &
       Spectrum_W      = 1.0/nWave , &
       SpectrumPlus_W  = 2.0/nWave , &
       SpectrumMinus_W = 2.0/nWave

  ! Set the default type of spectral function. Default may be changed by using
  ! the #SPECTRUM command in PARM.in
  character(LEN=10)::  NameSpectralFunction = 'uniform'

  !Parameters for different kinds of the specrral function
  !For Planckian: not implemented
  !real:: TRadSpectrum, EnergyMin

  !For power law: I\propto 1/f^{PowerIndex}, f> FreqStartSi

  !This is the default power index the spectral function. 
  ! The power law can be set to a different value by the #SPECTRUM command.
  ! Note: PowerIndex is only used when NameSpectralFunction=='powerlaw'
  real:: PowerIndex = 5.0/3.0, FreqStartSi = -1.0

  real :: WaveEnergy = 0.0 !Auxiliary variable
  real :: DivU_C(nI,nJ,nK) = 0.0       !Auxiliary variable


  ! Variables for incompressible turbulence.
  ! For now the ratio of magnetic to kinetic turbulence energy is assumed
  ! to be uniform (as provided by SigmaD, corresponding to Alfven ratio 1/2).
  logical :: UseAlfvenWaveReflection = .false.
  logical :: UseTransverseTurbulence = .true.
  real :: SigmaD = -1.0/3.0 ! Normalized energy difference

contains
  !============================================================================
  subroutine read_waves_param(NameCommand)

    use ModReadParam, ONLY: read_var

    character(len=*), intent(in):: NameCommand

    character(len=*), parameter:: NameSub = 'read_waves_param'
    !-------------------------------------------------------------------------
    select case(NameCommand)
    case("#WAVEREFLECTION")
       call read_var('UseAlfvenWaveReflection', UseAlfvenWaveReflection)
       call read_var('UseTransverseTurbulence', UseTransverseTurbulence)
    case("#ADVECTWAVES")
       call read_var('DoAdvectWaves', DoAdvectWaves)
    case("#ALFVENWAVES")
       call read_var('UseAlfvenWaves', UseAlfvenWaves)
    case("#SPECTRUM")
 
       ! Set type of spectral function.
       ! Default type is 'uniform', representing a uniform (gray) spectrum.
       ! In this case the value of PowerIndex will not be used.
       ! If NameSpectralFunction=='powerlaw', 
       ! PowerIndex should be set to the right value.

       call read_var('NameSpectralFunction',NameSpectralFunction)
       if(NameSpectralFunction == "powerlaw") &
            call read_var('PowerIndex',PowerIndex)

    case("#WAVEPRESSURE")
       call read_var('UseWavePressure'   ,UseWavePressure)
       call read_var('UseWavePressureLtd',UseWavePressureLtd)
    case("#FREQUENCY")
       call read_var('FreqMinSI',FreqMinSI)
       call read_var('FreqMaxSI',FreqMaxSI)
    case default
       call stop_mpi(NameSub//": unknown command="//trim(NameCommand))
    end select

  end subroutine read_waves_param
  !============================================================================
  subroutine check_waves
    integer:: iWave
    !--------------------------------------------------------------------------
    if(UseAlfvenWaves .and. 2*nWaveHalf /= nWave)call stop_mpi(&
         'nWave should be positive even when Alfven waves are used')

    if(UseAlfvenWaves          .and. &
         FreqMinSI > 0.0       .and. &
         FreqMaxSi > FreqMinSi .and. &
         nWaveHalf > 1             ) &
         DeltaLogFrequency = log( FreqMaxSI / FreqMinSI ) / nWaveHalf

    if( (.not.UseAlfvenWaves)  .and. &
         FreqMinSI > 0.0       .and. &
         FreqMaxSi > FreqMinSi .and. &
         nWave > 1           ) &
         DeltaLogFrequency = log( FreqMaxSI / FreqMinSI ) / nWave

    if(FreqMinSi > 0           .and. &
         FreqMaxSi > FreqMinSi   .and. &
         DeltaLogFrequency > 0.0)then

       !set bin-centered frequencies

       if(UseAlfvenWaves)then

          FrequencySi_W(AlfvenWavePlusFirst_) = &
               FreqMinSi * exp( 0.50 * DeltaLogFrequency)

          do iWave = AlfvenWavePlusFirst_+ 1, AlfvenWavePlusLast_
             FrequencySi_W(iWave) = FrequencySi_W(iWave - 1) * &
                  exp( DeltaLogFrequency )
          end do

          FrequencySi_W(AlfvenWaveMinusFirst_:AlfvenWaveMinusLast_) = &
               FrequencySi_W(AlfvenWavePlusFirst_:AlfvenWavePlusLast_)
       else

          FrequencySi_W(WaveFirst_) = FreqMinSi * exp(0.5*DeltaLogFrequency)

          do iWave = WaveFirst_ + 1, WaveLast_
             FrequencySi_W(iWave) = FrequencySi_W(iWave - 1) * &
                  exp( DeltaLogFrequency )
          end do
       end if
    end if
    !Set spectral functions

    SpectrumMinus_W = 0.0; SpectrumPlus_W = 0.0

    select case(NameSpectralFunction)

    case('uniform')
       Spectrum_W = 1.0/nWave

       if(UseAlfvenWaves)then        
          SpectrumPlus_W(AlfvenWavePlusFirst_:AlfvenWavePlusLast_) &
               = 1.0/nWaveHalf
          SpectrumMinus_W(AlfvenWaveMinusFirst_:AlfvenWaveMinusLast_) &
               = 1.0/nWaveHalf
       end if
    case('powerlaw')
       if(any(FrequencySi_W <= 0.0))call stop_mpi(&
            'Power law spectrum cannot be set for not-positive frequencies')
       if(all(FrequencySi_W < FreqStartSi))call stop_mpi(&
            'All bin-centered frequencies are below the start frequency for spectrum')

       where(FrequencySi_W >= FreqStartSi)&
            Spectrum_W = 1.0 / FrequencySi_W**(PowerIndex - 1.0)

       !Normalize by unity:
       Spectrum_W = Spectrum_W/sum(Spectrum_W)

       if(UseAlfvenWaves)then

          where(FrequencySi_W(&
               AlfvenWavePlusFirst_:AlfvenWavePlusLast_) >= FreqStartSi)&
               SpectrumPlus_W(&
               AlfvenWavePlusFirst_:AlfvenWavePlusLast_) = 1.0 / &
               FrequencySi_W(&
               AlfvenWavePlusFirst_:AlfvenWavePlusLast_)**(PowerIndex - 1.0)

          where(FrequencySi_W(&
               AlfvenWaveMinusFirst_:AlfvenWaveMinusLast_) >= FreqStartSi)&
               SpectrumMinus_W(&
               AlfvenWaveMinusFirst_:AlfvenWaveMinusLast_) = 1.0 / &
               FrequencySi_W(&
               AlfvenWaveMinusFirst_:AlfvenWaveMinusLast_)**(PowerIndex - 1.0)

          !Normalize by unity:
          SpectrumPlus_W  = SpectrumPlus_W  /sum(SpectrumPlus_W)
          SpectrumMinus_W = SpectrumMinus_W /sum(SpectrumMinus_W)
       end if
    case default
       call stop_mpi(&
            'Spectral function '//NameSpectralFunction//' is not implemented')
    end select
  end subroutine check_waves
  !============================================================================
  subroutine set_wave_state(EWaveTotal, State_V, Xyz_D, B0_D)
    use ModVarIndexes, ONLY: nVar, Bx_, Bz_, Ew_
    use ModMain, ONLY: MaxDim, UseB0

    !Input and output parameters:

    !Total energy density of waves
    real, intent(in)    :: EWaveTotal  

    !WaveFirst_:WaveLast_ components of this vector are to be filled in:
    real, intent(inout) :: State_V(nVar)  

    !If UseAlfvenWaves, the Plus or Minus waves are intialized, depending on
    !the sign of {\bf B}\cdot{\bf r}, therefore, we need the following optional
    !parameters:
    real, intent(in), optional:: Xyz_D(MaxDim), B0_D(MaxDim)

    real:: BTotal_D(MaxDim)
    !-------------------------------------------------------------------------
    if(UseAlfvenWaves)then

       BTotal_D = State_V(Bx_:Bz_)
       if(UseB0) BTotal_D = BTotal_D + B0_D

       !Figure out the sign of {\bf B}\cdot{\bf r}
       if( sum( BTotal_D*Xyz_D ) > 0) then

          State_V(WaveFirst_:WaveLast_) = EWaveTotal * SpectrumPlus_W

       else

          State_V(WaveFirst_:WaveLast_) = EWaveTotal * SpectrumMinus_W

       end if
    else
       State_V(WaveFirst_:WaveLast_) = EWaveTotal * Spectrum_W
    end if
    if( UseWavePressureLtd )&
         State_V(Ew_) = sum(State_V(WaveFirst_:WaveLast_))

  end subroutine set_wave_state

  !============================================================================

  subroutine update_wave_group_advection(iBlock)
    use ModAdvance,           ONLY: State_VGB, time_blk
    use ModGeometry,          ONLY: true_cell
    use ModLinearAdvection,   ONLY: advance_lin_advection_plus, &
         advance_lin_advection_minus
    use ModMain,              ONLY: CFL
    Use ModFaceValue,         ONLY: BetaLimiter
    use BATL_lib,             ONLY: Xyz_DGB

    integer,intent(in)    ::iBlock

    !\
    !Soution vector, to account for zero boundary condition
    !a single layer of the ghost cels is added
    !/
    real:: F_I(0:nWave+1), F2_I( 0: nWaveHalf+1)


    !\
    !Auxiiary vector of CFL numbers:
    !/
    real:: CFL_I(1:nWave), CFL2_I(1:nWaveHalf)

    !\
    !Loop variables:
    !/
    integer :: i,j,k

    logical :: IsNegativeEnergy
    !-------------------------------------------------------------------------
    if(DeltaLogFrequency<= 0.0                   &
         .or. (UseAlfvenWaves .and. nWaveHalf==1) &
         .or.((.not.UseAlfvenWaves ).and. nWave==1))RETURN

    if(UseAlfvenWaves)then

       do k= 1, nK; do j= 1,nJ; do i= 1,nI
          if(.not. true_cell(i,j,k,iBlock)) CYCLE

          CFL2_I = abs( DivU_C(i,j,k) ) * (GammaWave - 1.0)/&
               DeltaLogFrequency * CFL * time_blk(i,j,k, iBlock)
          ! Boundary conditions
          F2_I(0) = 0.0 ; F2_I(nWaveHalf+1) = 0.0
          if(DivU_C(i,j,k)>0.0)then

             F2_I( 1:nWaveHalf) = &
                  State_VGB(AlfvenWavePlusFirst_:AlfvenWavePlusLast_,i,j,k,iBlock)
             F2_I(nWaveHalf+1)=F2_I(nWaveHalf)
             call advance_lin_advection_minus( CFL2_I, nWaveHalf, 1, 1, F2_I, &
                  BetaLimiter, UseConservativeBC= .true., IsNegativeEnergy= IsNegativeEnergy)
             if(IsNegativeEnergy)call write_and_stop

             State_VGB(AlfvenWavePlusFirst_:AlfvenWavePlusLast_, i,j,k, iBlock) = &
                  F2_I( 1:nWaveHalf)

             F2_I( 1:nWaveHalf) = &
                  State_VGB(AlfvenWaveMinusFirst_:AlfvenWaveMinusLast_, i,j,k, iBlock)

             F2_I(nWaveHalf+1) = F2_I(nWaveHalf)
             call advance_lin_advection_minus( CFL2_I, nWaveHalf, 1, 1, F2_I, &
                  BetaLimiter, UseConservativeBC= .true., IsNegativeEnergy= IsNegativeEnergy)
             if(IsNegativeEnergy)call write_and_stop

             State_VGB(AlfvenWaveMinusFirst_:AlfvenWaveMinusLast_, i,j,k, iBlock) = &
                  F2_I( 1:nWaveHalf)
          else

             F2_I( 1:nWaveHalf) = &
                  State_VGB(AlfvenWavePlusFirst_:AlfvenWavePlusLast_, i,j,k, iBlock)
             F2_I(0) = F2_I(1) 

             call advance_lin_advection_plus( CFL2_I, nWaveHalf, 1, 1, F2_I, &
                  BetaLimiter, UseConservativeBC= .true., IsNegativeEnergy= IsNegativeEnergy)
             if(IsNegativeEnergy) call write_and_stop

             State_VGB(AlfvenWavePlusFirst_:AlfvenWavePlusLast_, i,j,k, iBlock) = &
                  F2_I( 1:nWaveHalf)

             F2_I( 1:nWaveHalf) = &
                  State_VGB(AlfvenWaveMinusFirst_:AlfvenWaveMinusLast_, i,j,k, iBlock)
             F2_I(0) = F2_I(1)
             call advance_lin_advection_plus( CFL2_I, nWaveHalf, 1, 1, F2_I, &
                  BetaLimiter, UseConservativeBC= .true., IsNegativeEnergy= IsNegativeEnergy)
             if(IsNegativeEnergy) call write_and_stop

             State_VGB(AlfvenWaveMinusFirst_:AlfvenWaveMinusLast_, i,j,k, iBlock) = &
                  F2_I( 1:nWaveHalf)
          end if

       end do; end do; end do

    else

       !Boundary conditions at very low and very high frequency:
       F_I(0) = 0.0; F_I(nWave+1) = 0.0

       do k = 1, nK; do j = 1, nJ; do i = 1, nI
          if(.not. true_cell(i,j,k,iBlock)) CYCLE

          CFL_I = abs( DivU_C(i,j,k) ) * (GammaWave - 1.0)/&
               DeltaLogFrequency * CFL * time_blk(i,j,k,iBlock)

          F_I(1:nWave) = &
               max(State_VGB(WaveFirst_:WaveLast_,i,j,k,iBlock), 1e-30)

          if(DivU_C(i,j,k) > 0.0)then
             F_I(nWave + 1)=F_I(nWave)
             call advance_lin_advection_minus( CFL_I, nWave, 1, 1, F_I, &
                  UseConservativeBC= .true.) 
          else
             F_I(0) = F_I(1)
             call advance_lin_advection_plus( CFL_I, nWave, 1, 1, F_I, &
                  UseConservativeBC= .true.)
          end if

          State_VGB(WaveFirst_:WaveLast_,i,j,k,iBlock) = F_I(1:nWave)

       end do; end do; end do
    end if

  contains
    !=========================================================================
    subroutine write_and_stop
      use ModVarIndexes, ONLY: nVar, NameVar_V
      integer:: iVar
      !-----------------------------------------------------------------------
      write(*,*) 'Negative energy density in xyz=',Xyz_DGB(:,i,j,k,iBlock), &
           ' ijk=', i, j, k, ' iBlock=',iBlock
      write(*,*)'Var      State_VGB(iVar,i,j,k,iBlock)'

      do iVar=1,nVar
         write(*,*) NameVar_V(iVar), State_VGB(iVar,i,j,k,iBlock)
      end do

      call stop_mpi('Stopped')
    end subroutine write_and_stop

  end subroutine update_wave_group_advection

end module ModWaves
