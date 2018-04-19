/* iPIC3D was originally developed by Stefano Markidis and Giovanni Lapenta. 
 * This release was contributed by Alec Johnson and Ivy Bo Peng.
 * Publications that use results from iPIC3D need to properly cite  
 * 'S. Markidis, G. Lapenta, and Rizwan-uddin. "Multi-scale simulations of 
 * plasma with iPIC3D." Mathematics and Computers in Simulation 80.7 (2010): 1509-1519.'
 *
 *        Copyright 2015 KTH Royal Institute of Technology
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at 
 *
 *         http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */


#include "mpi.h"
#include "MPIdata.h"
#include "iPic3D.h"
#include "TimeTasks.h"
#include "ipicdefs.h"
#include "debug.h"
#include "Parameters.h"
#include "ompdefs.h"
#include "VCtopology3D.h"
#include "Collective.h"
#include "Grid3DCU.h"
#include "EMfields3D.h"
#include "Particles3D.h"
#include "Timing.h"
#include "ParallelIO.h"
#ifndef NO_HDF5
#include "WriteOutputParallel.h"
#include "OutputWrapperFPP.h"
#endif

#include <iostream>
#include <fstream>
#include <sstream>
#include <iomanip>

#include "Moments.h" // for debugging

using namespace std;
using namespace iPic3D;
//MPIdata* iPic3D::c_Solver::mpi=0;

MPI_Comm MPI_COMM_MYSIM;
#ifdef BATSRUS
bool isProc0;
#endif

c_Solver::~c_Solver()
{
  
#ifndef NO_HDF5
  delete outputWrapperFPP;
#endif
  // delete particles
  //
  if(part)
  {
    for (int i = 0; i < ns; i++)
    {
      // placement delete
      part[i].~Particles3D();
    }
    free(part);
  }

  delete [] Ke;
  delete [] momentum;
  delete [] BulkEnergy;
  delete [] Qremoved;
  delete my_clock;

  #ifdef BATSRUS
  finalize_debug_SWMF();

  delArr4(fieldwritebuffer,grid->getNZN()-3,grid->getNYN()-3,grid->getNXN()-3 );
  
  
  if(nPlotFile>0){
    delArr2(plotMin_ID,nPlotFile);
    delArr2(plotMax_ID,nPlotFile);
    delArr2(plotIdxLocMin_ID, nPlotFile);
    delArr2(plotIdxLocMax_ID, nPlotFile);
    
    for(int iPlot=0;iPlot<nPlotFile;iPlot++){
      for(int inode=0;inode<nNodeMax;inode++){
	delete [] pointList_IID[iPlot][inode];
      }
    }

    
    for(int iPlot=0;iPlot<nPlotFile;iPlot++){
      delete [] pointList_IID[iPlot];
      delete [] Var_II[iPlot];
    }

    delete [] pointList_IID;
    delete [] Var_II;

    delete [] nextOutputTime_I;
    delete [] lastOutputCycle_I;
    delete [] nVar_I;
    delete [] nCell_I;
    delete [] doSaveCellLoc_I;
    delete [] nameSnapshot_I;
    delete [] outputFormat_I;
    delete [] outputUnit_I;
    delete [] plotVar_I;
    delete [] doOutputParticles_I;
    delete [] iSpeciesOutput_I;
    delete [] isSat_I;
    delete [] nPoint_I;
    delete [] satInputFile_I;
    
  }
  #endif
  
  delete col; // configuration parameters ("collectiveIO")
  delete vct; // process topology
  delete grid; // grid
  delete EMf; // field
}

int c_Solver::Init(int argc, char **argv, double inittime,
		   stringstream *param, int iIPIC, int *paramint,
		   double *griddim, double *paramreal, stringstream *ss,
		   bool doCoupling){
#if defined(__MIC__)
  assert_eq(DVECWIDTH,8);
#endif
  // get MPI data
  //
  // c_Solver is not a singleton, so the following line was pulled out.
  //MPIdata::init(&argc, &argv);
  //
  // initialized MPI environment
  // nprocs = number of processors
  // myrank = rank of tha process*/
  Parameters::init_parameters();
  //mpi = &MPIdata::instance();
  nprocs = MPIdata::get_nprocs();
  myrank = MPIdata::get_rank();

  if(vct == NULL){
    // For coupling, the initialization has two stages.
    // First stage: initilize Collective and vct and get parameters
    // from BATSRUS.
    // Second stage: after get simulation parameters (dt, uth...) from BATSRUS,
    // finish the initilization.
    if(!doCoupling) col = new Collective(argc, argv); // Every proc loads the parameters of simulation from class Collective

#ifdef BATSRUS
    if(doCoupling){
      if (myrank == 0){
	cout << endl;cout << endl;cout << endl;
	cout << "****************************************************" << endl;
	cout << "               iPIC3D Input Parameters              " << endl;
	cout << "****************************************************" << endl;
      }
      col = new Collective(argc, argv, param, iIPIC, paramint,griddim, paramreal, ss); // Every proc loads the parameters of simulation from class Collective
      col->setSItime(inittime);
    }
#endif
  
    restart_cycle = col->getRestartOutputCycle();
    SaveDirName = col->getSaveDirName();
    RestartDirName = col->getRestartDirName();
    restart_status = col->getRestart_status();
    ns = col->getNs();            // get the number of particle species involved in simulation
    first_cycle = col->getLast_cycle() + 1; // get the last cycle from the restart
    // initialize the virtual cartesian topology
    vct = new VCtopology3D(*col);
    // Check if we can map the processes into a matrix ordering defined in Collective.cpp
    if (nprocs != vct->getNprocs()) {
      if (myrank == 0) {
	cerr << "Error: " << nprocs << " processes cant be mapped into " << vct->getXLEN() << "x" << vct->getYLEN() << "x" << vct->getZLEN() << " matrix: Change XLEN,YLEN, ZLEN in method VCtopology3D.init()" << endl;
	MPIdata::instance().finalize_mpi();
	return (1);
      }
    }
    // We create a new communicator with a 3D virtual Cartesian topology
    vct->setup_vctopology(MPI_COMM_MYSIM);
    {
      stringstream num_proc_ss;
      num_proc_ss << vct->getCartesian_rank();
      num_proc_str = num_proc_ss.str();
    }
    // initialize the central cell index

#ifdef BATSRUS
    if(col->getCase()=="BATSRUS") {
      col->setVCTpointer(vct);
      col->setGlobalStartIndex();
      return 0;
    }
#endif
  }
#ifdef BATSRUS
  // set index offset for each processor
  if(col->getCase()=="BATSRUS") {
    col->FinilizeInit();
  }
#endif

  // Print the initial settings to stdout and a file
  if (myrank == 0) {
    MPIdata::instance().Print();
    vct->Print();
    col->Print();
    col->save();
  }
  // Create the local grid
  grid = new Grid3DCU(col, vct);  // Create the local grid
  EMf = new EMfields3D(col, grid, vct);  // Create Electromagnetic Fields Object

  if      (col->getCase()=="Uniform") 		EMf->initUniform();
  else if (col->getCase()=="GEMnoPert") 		EMf->initGEMnoPert();
  else if (col->getCase()=="ForceFree") 		EMf->initForceFree();
  else if (col->getCase()=="GEM")       		EMf->initGEM();
  else if (col->getCase()=="GEMDoubleHarris")  	EMf->initGEMDoubleHarris();
#ifdef BATSRUS
  else if (col->getCase()=="BATSRUS")   EMf->initBATSRUS(vct,grid,col);
#endif
  else if (col->getCase()=="Dipole")    EMf->initDipole();
  else if (col->getCase()=="Dipole2D")  EMf->initDipole2D();
  else if (col->getCase()=="NullPoints")EMf->initNullPoints();
  else if (col->getCase()=="TaylorGreen")EMf->initTaylorGreen();
  else if (col->getCase()=="RandomCase") {
    EMf->initRandomField();
    if (myrank==0) {
      cout << "Case is " << col->getCase() <<"\n";
      cout <<"total # of particle per cell is " << col->getNpcel(0) << "\n";
    }
  }
  else {
    if (myrank==0) {
      cout << " =========================================================== " << endl;
      cout << " WARNING: The case '" << col->getCase() << "' was not recognized. " << endl;
      cout << "          Runing simulation with the default initialization. " << endl;
      cout << " =========================================================== " << endl;
    }
    EMf->init();
  }

#ifdef BATSRUS
  string nameSub = "C_Solver::Init";
  if(col->getCase()=="BATSRUS" && restart_status != 0){
    EMf->init();
    EMf->SyncWithFluid(col,grid,vct);    
  }

  if(!col->getdoNeedBCOnly() && col->getCase()=="BATSRUS"){
    col->setdoNeedBCOnly(true);
  }

  init_debug_SWMF(col,grid,vct,col->getTestFunc(),col->getiTest(),
		  col->getjTest(),col->getkTest());

  write_plot_init();
#endif

  // Allocation of particles
  part = (Particles3D*) malloc(sizeof(Particles3D)*ns);
  for (int i = 0; i < ns; i++)
  {
    new(&part[i]) Particles3D(i,col,vct,grid);
  }

  // Initial Condition for PARTICLES if you are not starting from RESTART
  if (restart_status == 0) {

    for (int i = 0; i < ns; i++)
    {
      if      (col->getCase()=="ForceFree") part[i].force_free(EMf);
#ifdef BATSRUS
      else if (col->getCase()=="BATSRUS")   part[i].MaxwellianFromFluid(EMf);
#endif
      else if (col->getCase()=="NullPoints")    	part[i].maxwellianNullPoints(EMf);
      else if (col->getCase()=="TaylorGreen")    	part[i].maxwellianNullPoints(EMf); // Flow is initiated from the current prescribed on the grid.
      else if (col->getCase()=="GEMDoubleHarris")  	part[i].maxwellianDoubleHarris(EMf);
      else                                  part[i].maxwellian(EMf);
      part[i].reserve_remaining_particle_IDs();
    }    
  }
  
  //allocate test particles if any
  nstestpart = col->getNsTestPart();
  if(nstestpart>0){
	  testpart = (Particles3D*) malloc(sizeof(Particles3D)*nstestpart);
	  for (int i = 0; i < nstestpart; i++)
	  {
	     new(&testpart[i]) Particles3D(i+ns,col,vct,grid);//species id for test particles is increased by ns
	     testpart[i].pitch_angle_energy(EMf);
	   }
  }

  if ( Parameters::get_doWriteOutput()){
		#ifndef NO_HDF5
	  	if(col->getWriteMethod() == "shdf5" || col->getCallFinalize() || restart_cycle>0 ||
			  (col->getWriteMethod()=="pvtk" && !col->particle_output_is_off()) )
		{
			  outputWrapperFPP = new OutputWrapperFPP;
			  fetch_outputWrapperFPP().init_output_files(col,vct,grid,EMf,part,ns,testpart,nstestpart);
		}
		#endif
#ifdef BATSRUS
		fieldwritebuffer = newArr4(float,(grid->getNZN()-3),grid->getNYN()-3,grid->getNXN()-3,3);

#else
	  if(!col->field_output_is_off()){
		  if(col->getWriteMethod()=="pvtk"){
			  if(!(col->getFieldOutputTag()).empty())
				  fieldwritebuffer = newArr4(float,(grid->getNZN()-3),grid->getNYN()-3,grid->getNXN()-3,3);
			  if(!(col->getMomentsOutputTag()).empty())
				  momentwritebuffer=newArr3(float,(grid->getNZN()-3), grid->getNYN()-3, grid->getNXN()-3);
		  }
		  else if(col->getWriteMethod()=="nbcvtk"){
		    momentreqcounter=0;
		    fieldreqcounter = 0;
			  if(!(col->getFieldOutputTag()).empty())
				  fieldwritebuffer = newArr4(float,(grid->getNZN()-3)*4,grid->getNYN()-3,grid->getNXN()-3,3);
			  if(!(col->getMomentsOutputTag()).empty())
				  momentwritebuffer=newArr3(float,(grid->getNZN()-3)*14, grid->getNYN()-3, grid->getNXN()-3);
		  }
	  }
#endif
  }
  Ke = new double[ns];
  BulkEnergy = new double[ns];
  momentum = new double[ns];

  if(col->getCase()=="BATSRUS"){
#ifdef BATSRUS    
    stringstream logFile;
    logFile<<SaveDirName<<"/log_region"<<col->getiRegion()
	   <<"_n"<<setfill('0')<<setw(8)<<first_cycle<<".log";
    cq = logFile.str();
    if (myrank == 0) {
      ofstream my_file(cq.c_str());
      // What is the unit of bulk energy?? --Yuxi
      my_file<<"time nstep Moment Etotal Eefield Ebfield Epart ";
      for (int is = 0; is < ns; is++) my_file << " Epart" <<is;
      //for (int is = 0; is < ns; is++) my_file <<" Ebulk"<<is;
      my_file<<endl;
      my_file.close();
    }
#endif
  }else{
    cq = SaveDirName + "/ConservedQuantities.txt";
    if (myrank == 0) {
      ofstream my_file(cq.c_str());
      my_file.close();
    }
  }

  Qremoved = new double[ns];

  my_clock = new Timing(myrank);

  return 0;
}

void c_Solver::CalculateMoments(bool doCleanDivEIn) {

  timeTasks_set_main_task(TimeTasks::MOMENTS);

  pad_particle_capacities();

  // vectorized assumes that particles are sorted by mesh cell
  if(Parameters::get_VECTORIZE_MOMENTS())
  {
    switch(Parameters::get_MOMENTS_TYPE())
    {
      case Parameters::SoA:
        // since particles are sorted,
        // we can vectorize interpolation of particles to grid
        convertParticlesToSoA();
        sortParticles();
        EMf->sumMoments_vectorized(part);
        break;
      case Parameters::AoS:
        convertParticlesToAoS();
        sortParticles();
        EMf->sumMoments_vectorized_AoS(part);
        break;
      default:
        unsupported_value_error(Parameters::get_MOMENTS_TYPE());
    }
  }
  else
  {
    if(Parameters::get_SORTING_PARTICLES())
      sortParticles();
    switch(Parameters::get_MOMENTS_TYPE())
    {
      case Parameters::SoA:
        EMf->setZeroPrimaryMoments();
        convertParticlesToSoA();
        EMf->sumMoments(part);
        break;
      case Parameters::AoS
	:
	convertParticlesToAoS();		
#ifdef BATSRUS
	if(doCleanDivEIn && col->get_doCleanDivE()){
	  // Do not clean divE by changing particle position/weight at the
	  // initilization stage. 	

	  string divEClean = col->get_divECleanType();
	  for(int iNonLinear=0; iNonLinear < col->get_nIterNonLinear(); 
	      iNonLinear++){
	    
	    EMf->setZeroDerivedMoments(); // move this part into calc_cell_center_density!!!!!!!  -- Yuxi
	    EMf->calc_cell_center_density(part,false);	  
	    
	    if(divEClean == "position_estimate_phi"){
	      EMf->calculate_PHI(iPIC3D_PoissonImage,
				 col->get_divECleanTol(),
				 col->get_divECleanIter(), true);

	    }else if(divEClean.find("estimate") == string::npos){
	      EMf->calculate_PHI(iPIC3D_matvec_weight_correction,
				 col->get_divECleanTol(),
				 col->get_divECleanIter(), false);
	    }
	   
	    int isLight = col->get_iSpeciesLightest();
	    if(divEClean.substr(0,6)=="weight"){
	      part[isLight].correctWeight(EMf,divEClean);
	    } else if(divEClean.substr(0,8)=="position"){
	      int ns = col->getNs();
	      bool doCorrectAll = (divEClean=="position_all");
	      for(int is=0; is<ns; is++){
		if(is==isLight || doCorrectAll){
		  part[is].correctPartPos(EMf, divEClean);
		  part[is].delete_outside_particles();
		  part[is].separate_and_send_particles();
		  part[is].recommunicate_particles_until_done(1);
		}// if
	      }// for is
	    }
	  }// iNonLinear       
	}
#endif

	EMf->setZeroPrimaryMoments();
	EMf->sumMoments_AoS(part);
	
        break;
      case Parameters::AoSintr:
        EMf->setZeroPrimaryMoments();
        convertParticlesToAoS();
        EMf->sumMoments_AoS_intr(part);
        break;
      default:
        unsupported_value_error(Parameters::get_MOMENTS_TYPE());
    }
  }

  EMf->setZeroDerivedMoments();
  // sum all over the species
  EMf->sumOverSpecies();
  // Fill with constant charge the planet
  if (col->getCase()=="Dipole") {
    EMf->ConstantChargePlanet(col->getL_square(),col->getx_center(),col->gety_center(),col->getz_center());
  }else if(col->getCase()=="Dipole2D") {
	EMf->ConstantChargePlanet2DPlaneXZ(col->getL_square(),col->getx_center(),col->getz_center());
  }

  EMf->calc_cell_center_density(part,true); 


#ifdef BATSRUS
  EMf->calculateFluidPressure();
#endif
  
#ifndef BATSRUS
    // calculate the hat quantities for the implicit method
  EMf->calculateHatFunctions();
#endif
}

//! MAXWELL SOLVER for Efield
void c_Solver::CalculateField(int cycle) {
  timeTasks_set_main_task(TimeTasks::FIELDS);

#ifdef BATSRUS
  // Hat functions calculation need the information at boundaries.
  // For MH-iPIC3D, the boundary information is sent from MHD to
  // iPIC at the beginning of each cycle, so it is better to calculate
  // hat functions just before field calculation.
  EMf->calculateHatFunctions();
#endif

  // calculate the E field
  EMf->calculateE(cycle);
}

//! MAXWELL SOLVER for Bfield (assuming Efield has already been calculated)
void c_Solver::CalculateB() {
  timeTasks_set_main_task(TimeTasks::FIELDS);
  // calculate the B field
  EMf->calculateB();
}

/*  -------------- */
/*!  Particle mover */
/*  -------------- */
bool c_Solver::ParticlesMover()
{
#ifdef BATSRUS
  if(col->getdoTestEMWave()) return false;
#endif
  
  // move all species of particles
  {
    timeTasks_set_main_task(TimeTasks::PARTICLES);
    // Should change this to add background field
    EMf->set_fieldForPcls();

    pad_particle_capacities();

    for (int i = 0; i < ns; i++)  // move each species
    {
      #ifdef BATSRUS
      part[i].setDt(col->getDt());
      #endif
      // #pragma omp task inout(part[i]) in(grid) target_device(booster)
      // should merely pass EMf->get_fieldForPcls() rather than EMf.
      // use the Predictor Corrector scheme to move particles
      switch(Parameters::get_MOVER_TYPE())
      {
        case Parameters::SoA:
          part[i].mover_PC(EMf);
          break;
        case Parameters::AoS:
	  if(col->getuseExplicitMover()){
	    part[i].mover_PC_AoS_explicit(EMf);
	  }else{
	    part[i].mover_PC_AoS(EMf);
	  }
          break;
        case Parameters::AoS_Relativistic:
	  part[i].mover_PC_AoS_Relativistic(EMf);
	  break;
        case Parameters::AoSintr:
          part[i].mover_PC_AoS_vec_intr(EMf);
          break;
        case Parameters::AoSvec:
          part[i].mover_PC_AoS_vec(EMf);
          break;
        default:
          unsupported_value_error(Parameters::get_MOVER_TYPE());
      }

#ifdef BATSRUS
    for (int i = 0; i < ns; i++)  // communicate each species
      {
	part[i].delete_outside_particles();
      }
#endif

      
      // part[i].print_particles("after move");
      //Should integrate BC into separate_and_send_particles
      part[i].openbc_particles_outflow();
      part[i].separate_and_send_particles();
    }
    
    for (int i = 0; i < ns; i++)  // communicate each species
    {
      //part[i].communicate_particles();
      part[i].recommunicate_particles_until_done(1);
    }
  }

  /* -------------------------------------- */
  /* Repopulate the buffer zone at the edge */
  /* -------------------------------------- */

  for (int i=0; i < ns; i++) {
    if (col->getRHOinject(i)>0.0 || col->getCase()=="BATSRUS")
      part[i].repopulate_particles();
  }

  /* --------------------------------------- */
  /* Remove particles from depopulation area */
  /* --------------------------------------- */
  if (col->getCase()=="Dipole") {
    for (int i=0; i < ns; i++)
      Qremoved[i] = part[i].deleteParticlesInsideSphere(col->getL_square(),col->getx_center(),col->gety_center(),col->getz_center());
  }else if (col->getCase()=="Dipole2D") {
	for (int i=0; i < ns; i++)
	  Qremoved[i] = part[i].deleteParticlesInsideSphere2DPlaneXZ(col->getL_square(),col->getx_center(),col->getz_center());
  }


  /* --------------------------------------- */
  /* Test Particles mover 					 */
  /* --------------------------------------- */
  for (int i = 0; i < nstestpart; i++)  // move each species
  {
	switch(Parameters::get_MOVER_TYPE())
	{
	  case Parameters::SoA:
		  testpart[i].mover_PC(EMf);
		break;
	  case Parameters::AoS:
		  testpart[i].mover_PC_AoS(EMf);
		break;
	  case Parameters::AoS_Relativistic:
		  testpart[i].mover_PC_AoS_Relativistic(EMf);
		break;
	  case Parameters::AoSintr:
		  testpart[i].mover_PC_AoS_vec_intr(EMf);
		break;
	  case Parameters::AoSvec:
		  testpart[i].mover_PC_AoS_vec(EMf);
		break;
	  default:
		unsupported_value_error(Parameters::get_MOVER_TYPE());
	}

	testpart[i].openbc_delete_testparticles();
	testpart[i].separate_and_send_particles();
  }

  for (int i = 0; i < nstestpart; i++)
  {
	  testpart[i].recommunicate_particles_until_done(1);
  }

  process_mem_usage("After moving particles: ");
  
  return (false);
}

void c_Solver::WriteOutput(int cycle, bool doForceOutput) {
#ifdef BATSRUS
  write_plot_idl(cycle, doForceOutput);
  if(col->getWriteMethod()=="pvtk" && col->getFieldOutputCycle()>0 && (cycle%col->getFieldOutputCycle()==0 || cycle==first_cycle)){
    WriteFieldsVTK(grid, EMf, col, vct, "B + E + Je + Ji + rho",cycle, fieldwritebuffer);
  }
  WriteConserved(cycle);    
#else

    WriteConserved(cycle);
    WriteRestart(cycle);
  
    if(!Parameters::get_doWriteOutput())  return;
    if (col->getWriteMethod() == "nbcvtk"){//Non-blocking collective MPI-IO
	  if(!col->field_output_is_off() && (cycle%(col->getFieldOutputCycle()) == 0 || cycle == first_cycle) ){
		  if(!(col->getFieldOutputTag()).empty()){

			  if(fieldreqcounter>0){
			    //MPI_Waitall(fieldreqcounter,&fieldreqArr[0],&fieldstsArr[0]);
				  for(int si=0;si< fieldreqcounter;si++){
				    int error_code = MPI_File_write_all_end(fieldfhArr[si],&fieldwritebuffer[si][0][0][0],&fieldstsArr[si]);//fieldstsArr[si].MPI_ERROR;
					  if (error_code != MPI_SUCCESS) {
						  char error_string[100];
						  int length_of_error_string, error_class;
						  MPI_Error_class(error_code, &error_class);
						  MPI_Error_string(error_class, error_string, &length_of_error_string);
						  dprintf("MPI_Waitall error at field output cycle %d  %d  %s\n",cycle, si, error_string);
					  }else{
						  MPI_File_close(&(fieldfhArr[si]));
					  }
				  }
			  }
			  fieldreqcounter = WriteFieldsVTKNonblk(grid, EMf, col, vct,cycle,fieldwritebuffer,fieldreqArr,fieldfhArr);
		  }

		  if(!(col->getMomentsOutputTag()).empty()){

			  if(momentreqcounter>0){
				  MPI_Waitall(momentreqcounter,&momentreqArr[0],&momentstsArr[0]);
				  for(int si=0;si< momentreqcounter;si++){
					  int error_code = momentstsArr[si].MPI_ERROR;
					  if (error_code != MPI_SUCCESS) {
						  char error_string[100];
						  int length_of_error_string, error_class;
						  MPI_Error_class(error_code, &error_class);
						  MPI_Error_string(error_class, error_string, &length_of_error_string);
						  dprintf("MPI_Waitall error at moments output cycle %d  %d %s\n",cycle, si, error_string);
					  }else{
						  MPI_File_close(&(momentfhArr[si]));
					  }
				  }
			  }
			  momentreqcounter = WriteMomentsVTKNonblk(grid, EMf, col, vct,cycle,momentwritebuffer,momentreqArr,momentfhArr);
		  }
	  }

	  //Particle information is still in hdf5
	  	WriteParticles(cycle);
	  //Test Particle information is still in hdf5
	    WriteTestParticles(cycle);

  }else if (col->getWriteMethod() == "pvtk"){//Blocking collective MPI-IO
	  if(!col->field_output_is_off() && (cycle%(col->getFieldOutputCycle()) == 0 || cycle == first_cycle) ){
		  if(!(col->getFieldOutputTag()).empty()){
			  //WriteFieldsVTK(grid, EMf, col, vct, col->getFieldOutputTag() ,cycle);//B + E + Je + Ji + rho
			  WriteFieldsVTK(grid, EMf, col, vct, col->getFieldOutputTag() ,cycle, fieldwritebuffer);//B + E + Je + Ji + rho
		  }
		  if(!(col->getMomentsOutputTag()).empty()){
			  WriteMomentsVTK(grid, EMf, col, vct, col->getMomentsOutputTag() ,cycle, momentwritebuffer);
		  }
	  }

	  //Particle information is still in hdf5
	  	WriteParticles(cycle);
	  //Test Particle information is still in hdf5
	    WriteTestParticles(cycle);

  }else{

		#ifdef NO_HDF5
			eprintf("The selected output option must be compiled with HDF5");

		#else
			if (col->getWriteMethod() == "H5hut"){

			  if (!col->field_output_is_off() && cycle%(col->getFieldOutputCycle())==0)
				WriteFieldsH5hut(ns, grid, EMf, col, vct, cycle);
			  if (!col->particle_output_is_off() && cycle%(col->getParticlesOutputCycle())==0)
				WritePartclH5hut(ns, grid, part, col, vct, cycle);

			}else if (col->getWriteMethod() == "phdf5"){

			  if (!col->field_output_is_off() && cycle%(col->getFieldOutputCycle())==0)
				WriteOutputParallel(grid, EMf, part, col, vct, cycle);

			  if (!col->particle_output_is_off() && cycle%(col->getParticlesOutputCycle())==0)
			  {
				if(MPIdata::get_rank()==0)
				  warning_printf("WriteParticlesParallel() is not yet implemented.");
			  }

			}else if (col->getWriteMethod() == "shdf5"){

					WriteFields(cycle);

					WriteParticles(cycle);

					WriteTestParticles(cycle);

			}else{
			  warning_printf(
				"Invalid output option. Options are: H5hut, phdf5, shdf5, pvtk");
			  invalid_value_error(col->getWriteMethod().c_str());
			}
		#endif
    }
#endif
}

void c_Solver::WriteRestart(int cycle)
{
#ifndef NO_HDF5
  if ((restart_cycle>0 && cycle%restart_cycle==0) || col->getCase()=="BATSRUS"){
	  convertParticlesToSynched();
	  fetch_outputWrapperFPP().append_restart(cycle);

	  stringstream settingFile;
	  
	  settingFile<<"settings";
#ifdef BATSRUS
	  settingFile<<"_region"<<col->getiRegion();
#endif
	  settingFile<<".hdf";
	  
	  if(myrank==0)fetch_outputWrapperFPP().append_restart_setting(settingFile.str());
  }
#endif
}

// write the conserved quantities
void c_Solver::WriteConserved(int cycle) {
  if((col->getDiagnosticsOutputCycle() > 0 && cycle % col->getDiagnosticsOutputCycle() == 0) || cycle==0)
  {
    Eenergy = EMf->getEenergy();
    Benergy = EMf->getBenergy();
    TOTenergy = 0.0;
    TOTmomentum = 0.0;
    for (int is = 0; is < ns; is++) {
      Ke[is] = part[is].getKe();
      BulkEnergy[is] = EMf->getBulkEnergy(is);
      TOTenergy += Ke[is];
      momentum[is] = part[is].getP();
      TOTmomentum += momentum[is];
    }
    if (myrank == (nprocs-1)) {
      ofstream my_file(cq.c_str(), fstream::app);
      if(col->getCase()=="BATSRUS"){
#ifdef BATSRUS
	my_file.precision(12);
	my_file<<std::scientific;
	my_file<<getSItime()<<"\t"<<cycle<< "\t" << TOTmomentum<< "\t"<< (Eenergy + Benergy + TOTenergy)<< "\t" << Eenergy << "\t" << Benergy << "\t" << TOTenergy;
	for (int is = 0; is < ns; is++) my_file << "\t" << Ke[is];
	//for (int is = 0; is < ns; is++) my_file << "\t" << BulkEnergy[is];
#endif
      }else{
	if(cycle == 0) my_file << "\t" << "\t" << "\t" << "Total_Energy" << "\t" << "Momentum" << "\t" << "Eenergy" << "\t" << "Benergy" << "\t" << "Kenergy" << "\t" << "Kenergy(species)" << "\t" << "BulkEnergy(species)" << endl;
	my_file << cycle << "\t" << "\t" << (Eenergy + Benergy + TOTenergy) << "\t" << TOTmomentum << "\t" << Eenergy << "\t" << Benergy << "\t" << TOTenergy;
	for (int is = 0; is < ns; is++) my_file << "\t" << Ke[is];
	for (int is = 0; is < ns; is++) my_file << "\t" << BulkEnergy[is];      
      }
      my_file << endl;
      my_file.close();
    }
  }
}
/* write the conserved quantities
void c_Solver::WriteConserved(int cycle) {
  if(col->getDiagnosticsOutputCycle() > 0 && cycle % col->getDiagnosticsOutputCycle() == 0)
  {
	if(cycle==0)buf_counter=0;
    Eenergy[buf_counter] = EMf->getEenergy();
    Benergy[buf_counter] = EMf->getBenergy();
    Kenergy[buf_counter] = 0.0;
    TOTmomentum[buf_counter] = 0.0;
    for (int is = 0; is < ns; is++) {
      Ke[is] = part[is].getKe();
      Kenergy[buf_counter] += Ke[is];
      momentum[is] = part[is].getP();
      TOTmomentum[buf_counter] += momentum[is];
    }
    outputcycle[buf_counter] = cycle;
    buf_counter ++;

    //Flush out result if this is the last cycle or the buffer is full
    if(buf_counter==OUTPUT_BUFSIZE || cycle==(LastCycle()-1)){
    	if (myrank == (nprocs-1)) {
    		ofstream my_file(cq.c_str(), fstream::app);
    		stringstream ss;
      //if(cycle/OUTPUT_BUFSIZE == 0)
      //my_file  << "Cycle" << "\t" << "Total_Energy" 				 << "\t" << "Momentum" << "\t" << "Eenergy" <<"\t" << "Benergy" << "\t" << "Kenergy" << endl;
    		for(int bufid=0;bufid<OUTPUT_BUFSIZE;bufid++)
    			ss << outputcycle[bufid] << "\t" << (Eenergy[bufid]+Benergy[bufid]+Kenergy[bufid])<< "\t" << TOTmomentum[bufid] << "\t" << Eenergy[bufid] << "\t" << Benergy[bufid] << "\t" << Kenergy[bufid] << endl;

    		my_file << ss;
    		my_file.close();
    	}
    	buf_counter = 0;
    }
  }
}*/

void c_Solver::WriteVelocityDistribution(int cycle)
{
  // Velocity distribution
  //if(cycle % col->getVelocityDistributionOutputCycle() == 0)
  {
    for (int is = 0; is < ns; is++) {
      double maxVel = part[is].getMaxVelocity();
      long long *VelocityDist = part[is].getVelocityDistribution(nDistributionBins, maxVel);
      if (myrank == 0) {
        ofstream my_file(ds.c_str(), fstream::app);
        my_file << cycle << "\t" << is << "\t" << maxVel;
        for (int i = 0; i < nDistributionBins; i++)
          my_file << "\t" << VelocityDist[i];
        my_file << endl;
        my_file.close();
      }
      delete [] VelocityDist;
    }
  }
}

// This seems to record values at a grid of sample points
//
void c_Solver::WriteVirtualSatelliteTraces()
{
  if(ns <= 2) return;
  assert_eq(ns,4);

  ofstream my_file(cqsat.c_str(), fstream::app);
  const int nx0 = grid->get_nxc_r();
  const int ny0 = grid->get_nyc_r();
  const int nz0 = grid->get_nzc_r();
  for (int isat = 0; isat < nsat; isat++) {
    for (int jsat = 0; jsat < nsat; jsat++) {
      for (int ksat = 0; ksat < nsat; ksat++) {
        int index1 = 1 + isat * nx0 / nsat + nx0 / nsat / 2;
        int index2 = 1 + jsat * ny0 / nsat + ny0 / nsat / 2;
        int index3 = 1 + ksat * nz0 / nsat + nz0 / nsat / 2;
        my_file << EMf->getBx(index1, index2, index3) << "\t" << EMf->getBy(index1, index2, index3) << "\t" << EMf->getBz(index1, index2, index3) << "\t";
        my_file << EMf->getEx(index1, index2, index3) << "\t" << EMf->getEy(index1, index2, index3) << "\t" << EMf->getEz(index1, index2, index3) << "\t";
        my_file << EMf->getJxs(index1, index2, index3, 0) + EMf->getJxs(index1, index2, index3, 2) << "\t" << EMf->getJys(index1, index2, index3, 0) + EMf->getJys(index1, index2, index3, 2) << "\t" << EMf->getJzs(index1, index2, index3, 0) + EMf->getJzs(index1, index2, index3, 2) << "\t";
        my_file << EMf->getJxs(index1, index2, index3, 1) + EMf->getJxs(index1, index2, index3, 3) << "\t" << EMf->getJys(index1, index2, index3, 1) + EMf->getJys(index1, index2, index3, 3) << "\t" << EMf->getJzs(index1, index2, index3, 1) + EMf->getJzs(index1, index2, index3, 3) << "\t";
        my_file << EMf->getRHOns(index1, index2, index3, 0) + EMf->getRHOns(index1, index2, index3, 2) << "\t";
        my_file << EMf->getRHOns(index1, index2, index3, 1) + EMf->getRHOns(index1, index2, index3, 3) << "\t";
      }}}
  my_file << endl;
  my_file.close();
}

void c_Solver::WriteFields(int cycle) {

#ifndef NO_HDF5
  if(col->field_output_is_off())   return;

  if(cycle % (col->getFieldOutputCycle()) == 0 || cycle == first_cycle)
  {
	  if(!(col->getFieldOutputTag()).empty())
		  	  fetch_outputWrapperFPP().append_output((col->getFieldOutputTag()).c_str(), cycle);//E+B+Js
	  if(!(col->getMomentsOutputTag()).empty())
		  	  fetch_outputWrapperFPP().append_output((col->getMomentsOutputTag()).c_str(), cycle);//rhos+pressure
  }
#endif
}

void c_Solver::WriteParticles(int cycle)
{
#ifndef NO_HDF5
  if(col->particle_output_is_off() || cycle%(col->getParticlesOutputCycle())!=0) return;

  // this is a hack
  for (int i = 0; i < ns; i++)
    part[i].convertParticlesToSynched();

  fetch_outputWrapperFPP().append_output((col->getPclOutputTag()).c_str(), cycle, 0);//"position + velocity + q "
#endif
}

void c_Solver::WriteTestParticles(int cycle)
{
#ifndef NO_HDF5
  if(nstestpart == 0 || col->testparticle_output_is_off() || cycle%(col->getTestParticlesOutputCycle())!=0) return;

  // this is a hack
  for (int i = 0; i < nstestpart; i++)
    testpart[i].convertParticlesToSynched();

  fetch_outputWrapperFPP().append_output("testpartpos + testpartvel+ testparttag", cycle, 0); // + testpartcharge
#endif
}

// This needs to be separated into methods that save particles
// and methods that save field data
//
void c_Solver::Finalize() {
  if (col->getCallFinalize() && Parameters::get_doWriteOutput())
  {
    #ifndef NO_HDF5
    convertParticlesToSynched();
    fetch_outputWrapperFPP().append_restart((col->getNcycles() + first_cycle) - 1);
    #endif
  }

  // stop profiling
  my_clock->stopTiming();
}

void c_Solver::sortParticles() {

  for(int species_idx=0; species_idx<ns; species_idx++)
    part[species_idx].sort_particles_serial();

}

void c_Solver::pad_particle_capacities()
{
  for (int i = 0; i < ns; i++)
    part[i].pad_capacities();

  for (int i = 0; i < nstestpart; i++)
    testpart[i].pad_capacities();
}

// convert particle to struct of arrays (assumed by I/O)
void c_Solver::convertParticlesToSoA()
{
  for (int i = 0; i < ns; i++)
    part[i].convertParticlesToSoA();
}

// convert particle to array of structs (used in computing)
void c_Solver::convertParticlesToAoS()
{
  for (int i = 0; i < ns; i++)
    part[i].convertParticlesToAoS();
}

// convert particle to array of structs (used in computing)
void c_Solver::convertParticlesToSynched()
{
  for (int i = 0; i < ns; i++)
    part[i].convertParticlesToSynched();

  for (int i = 0; i < nstestpart; i++)
    testpart[i].convertParticlesToSynched();
}

int c_Solver::LastCycle() {
  return (col->getNcycles() + first_cycle);
}

#ifdef BATSRUS
void c_Solver::SyncWithFluid(int cycle){  
  string nameSub="c_Solver::SyncWithFluid";
  unsigned long iSyncTimeStep;
  
  // read in the new fluid variables, next step
  iSyncTimeStep = col->doSyncWithFluid(cycle - first_cycle+1);
  if(iSyncTimeStep > 0 ) EMf->SyncWithFluid(col,grid,vct);
}

void c_Solver::GetNgridPnt(int &nPoint){
  col->GetNgridPnt(nPoint);
}

void c_Solver::GetGridPnt(double *Pos_I){
  col->GetGridPnt(Pos_I);
}

void c_Solver::setStateVar(double *State_I, int *iPoint_I){
  col->setStateVar(State_I, iPoint_I);
}

void c_Solver::getStateVar(int nDim, int nPoint, double *Xyz_I, double *data_I, int nVar){
  string nameSub="getStateVar";
  fetch_outputWrapperFPP().getFluidState(nDim, nPoint, Xyz_I, data_I, nVar);
}

void c_Solver::findProcForPoint(int nPoint, double *Xyz_I, int *iProc_I){
  col->findProcForPoint(vct, nPoint, Xyz_I, iProc_I);
}

double c_Solver::getDt(){
  return(col->getDt());
}

double c_Solver::getSItime(){
  return(col->getSItime());
}

void c_Solver::setSIDt(double SIDt, bool isSWMFDt){
  col->setSIDt(SIDt, isSWMFDt);
}

double c_Solver::calSIDt(){
  double dtMax;
  int iError;
  // dtMax is in normalized unit. 
  dtMax = EMf->calDtMax(col->getDx(), col->getDy(), col->getDz(), col->getDt(), iError);
  if(iError == -1 ){
    WriteOutput(col->getCycle(), true);
    eprintf("Error: The plasma is too hot! Maximum thermal velocity exceeds the limit %f, which is set by the command #CHECKSTOP. ", col->get_maxUth());
  }
  col->setmaxDt(dtMax);
  
  return col->calSIDt();
}

void c_Solver::updateSItime(){
  col->updateSItime();
}

void c_Solver::SetCycle(int iCycle){
  col->setCycle(iCycle);
}

void c_Solver:: write_plot_idl(int cycle, bool doForceOutput){
  /*
    This method is called from WriteOutput(). WriteOutput() is called from 
    ipic3d_interface.cpp after each iteration or at the finalization stage.
    There are three situations when output is needed:
    1) 'cycle' reaches the output cycle.
    2) Simulation time reaches the output point.
    3) doForceOutput is true. 

    At the finalization stage, this method will be called with doForceOutput = true.
    If the information at the same cycle has been written on the disk, then 
    the output will be skipped.
   */

  
  string nameSub = "write_plot_idl";
  bool doTestFunc;
  doTestFunc = do_test_func(nameSub);
  //---------------------------------------------
  
  if(doTestFunc) cout<<"Start "<<nameSub<<endl;

  if(nPlotFile<=0) return;

  for(int iPlot=0; iPlot<nPlotFile; iPlot++){
    int dnOutput;
    double dtOutput, timeNow, dtTiny;
    dnOutput = col->getdnOutput(iPlot);
    dtOutput = col->getdtOutput(iPlot);
    dtTiny = 1e-6*dtOutput; 
    timeNow  = col->getSItime();
    if(  (doForceOutput || (dnOutput > 0 && cycle % dnOutput==0) ||
	  (dtOutput > 0 && timeNow+dtTiny >= nextOutputTime_I[iPlot])) &&
	 lastOutputCycle_I[iPlot] != cycle){
      if(dtOutput > 0 && timeNow+dtTiny >= nextOutputTime_I[iPlot]) {
	nextOutputTime_I[iPlot] = floor((timeNow + dtTiny)/dtOutput+1)*dtOutput;
      }
      
      lastOutputCycle_I[iPlot] = cycle;
      set_output_unit(iPlot);
      write_plot_data(iPlot,cycle);

      // For particle output, header file needs the number of output
      // particles. So write header after write data. 
      write_plot_header(iPlot, cycle);
    }
  }
  

  if(doTestFunc) cout<<"Finish "<<nameSub<<endl;
}

void c_Solver:: write_plot_init(){
  string nameSub = "write_plot_init";
  bool doTestFunc;
  doTestFunc = do_test_func(nameSub);
  //-------------------

  nPlotFile = col->getnPlotFile();
  if(nPlotFile<=0) return;

  nNodeMax = grid->getNXN()*grid->getNYN()*grid->getNZN();

  IsBinary = col->getdoSaveBinary();
  
  plotMin_ID      = newArr2(double, nPlotFile, nDimMax);
  plotMax_ID      = newArr2(double, nPlotFile, nDimMax);
  plotIdxLocMin_ID = newArr2(int, nPlotFile, nDimMax);
  plotIdxLocMax_ID = newArr2(int, nPlotFile, nDimMax);
  nameSnapshot_I    = new string[nPlotFile];
  nVar_I            = new int[nPlotFile];
  nCell_I           = new long[nPlotFile];
  doSaveCellLoc_I   = new bool[nPlotFile];
  outputFormat_I    = new std::string[nPlotFile];
  outputUnit_I      = new std::string[nPlotFile];  
  plotVar_I         = new std::string[nPlotFile];
  doOutputParticles_I=new bool[nPlotFile];
  iSpeciesOutput_I  = new int[nPlotFile];
  nextOutputTime_I  = new double[nPlotFile];
  lastOutputCycle_I = new long[nPlotFile];
  Var_II            = new std::string*[nPlotFile];
  isSat_I           = new bool[nPlotFile];
  pointList_IID     = new double**[nPlotFile];
  nPoint_I          = new long[nPlotFile];
  
  //doSaveTrajectory_I= new bool[nPlotFile];
  satInputFile_I    = new string[nPlotFile];
  
  for(int iPlot=0;iPlot<nPlotFile;iPlot++){
    Var_II[iPlot]           = new std::string[nVarMax];
    pointList_IID[iPlot]      = new double*[nNodeMax];
    for(int inode=0; inode<nNodeMax; inode++){
      pointList_IID[iPlot][inode] = new double[3];
    }
  }

  for(int i=0;i<nPlotFile;i++){
    doOutputParticles_I[i] = false;
    nextOutputTime_I[i] = 0;
    lastOutputCycle_I[i] = -100;
    isSat_I[i] = false;
    nCell_I[i] = 0;
    doSaveCellLoc_I[i] = false;
    //doSaveTrajectory_I[i] = false;
  }

  string plotString;
  string subString;
  string::size_type pos;
  double dxSave;
  for(int iPlot=0; iPlot<nPlotFile; iPlot++){
    // plotString = plot range, plot variables, save format, output unit
    // Example:
    //   plotString =  'x=0 all real si'
    //   plotString =  '3d var ascii pic'
    //   plotString =  'cut var real planet'
    //   plotString =  'sat_sat01.dat particles01 ascii si'
    plotString = col->getplotString(iPlot);
    
    // Find the first sub-string: 'x=0',or 'y=1.2'.....
    pos = plotString.find_first_of(" \t\n");
    if(pos !=string::npos){
      subString = plotString.substr(0,pos);
    }else if(plotString.size()>0){
      subString = plotString;
    }
    nameSnapshot_I[iPlot] = SaveDirName + "/" + subString;

    double No2NoL = col->getMhdNo2NoL();
    
    // plotMin_ID/plotRangeMax_I is the range of the whole plot domain, it can be larger
    // than the simulation domain on this processor.
    stringstream ss;
    if(subString.substr(0,2)=="x="){
      subString.erase(0,2);
      ss<<subString;
      ss>>plotMin_ID[iPlot][x_];
      plotMin_ID[iPlot][x_] = plotMin_ID[iPlot][x_]*No2NoL - col->getFluidStartX();
      plotMax_ID[iPlot][x_] = plotMin_ID[iPlot][x_] + 1e-10;

      plotMin_ID[iPlot][y_] = 0;
      plotMax_ID[iPlot][y_] = col->getLy();
      plotMin_ID[iPlot][z_] = 0;
      plotMax_ID[iPlot][z_] = col->getLz();
    }else if(subString.substr(0,2)=="y="){
      subString.erase(0,2);
      ss<<subString;
      plotMin_ID[iPlot][x_] = 0;
      plotMax_ID[iPlot][x_] = col->getLx();
      ss>>plotMin_ID[iPlot][y_];
      plotMin_ID[iPlot][y_] = plotMin_ID[iPlot][y_]*No2NoL - col->getFluidStartY();
      plotMax_ID[iPlot][y_] = plotMin_ID[iPlot][y_] + 1e-10;
      plotMin_ID[iPlot][z_] = 0;
      plotMax_ID[iPlot][z_] = col->getLz();
    }else if(subString.substr(0,2)=="z="){
      subString.erase(0,2);
      ss<<subString;
      plotMin_ID[iPlot][x_] = 0;
      plotMax_ID[iPlot][x_] = col->getLx();
      plotMin_ID[iPlot][y_] = 0;
      plotMax_ID[iPlot][y_] = col->getLy();
      ss>>plotMin_ID[iPlot][z_];
      plotMin_ID[iPlot][z_] = plotMin_ID[iPlot][z_]*No2NoL - col->getFluidStartZ();
      plotMax_ID[iPlot][z_] = plotMin_ID[iPlot][z_] + 1e-10;
    }else if(subString.substr(0,2)=="3d" || subString.substr(0,2)=="1d"){
      plotMin_ID[iPlot][x_] = 0;
      plotMin_ID[iPlot][y_] = 0;
      plotMin_ID[iPlot][z_] = 0;
      plotMax_ID[iPlot][x_] = col->getLx();
      plotMax_ID[iPlot][y_] = col->getLy();
      plotMax_ID[iPlot][z_] = col->getLz();
    }else if(subString.substr(0,3)=="cut"){
      plotMin_ID[iPlot][x_] = col->getplotRangeMin(iPlot,x_)*No2NoL - col->getFluidStartX();
      plotMax_ID[iPlot][x_] = col->getplotRangeMax(iPlot,x_)*No2NoL - col->getFluidStartX();
      plotMin_ID[iPlot][y_] = col->getplotRangeMin(iPlot,y_)*No2NoL - col->getFluidStartY();
      plotMax_ID[iPlot][y_] = col->getplotRangeMax(iPlot,y_)*No2NoL - col->getFluidStartY();
      plotMin_ID[iPlot][z_] = col->getplotRangeMin(iPlot,z_)*No2NoL - col->getFluidStartZ();
      plotMax_ID[iPlot][z_] = col->getplotRangeMax(iPlot,z_)*No2NoL - col->getFluidStartZ();
    }else if(subString.substr(0,3)=="sat"){
      // sat_satFileName.sat

      isSat_I[iPlot] = true;
      subString.erase(0,4);
      ss<<subString;      
      ss>>satInputFile_I[iPlot];

      // For satellite output,plotRange is not meaningful. 
      plotMin_ID[iPlot][x_] = 0;
      plotMin_ID[iPlot][y_] = 0;
      plotMin_ID[iPlot][z_] = 0;
      plotMax_ID[iPlot][x_] = col->getLx();
      plotMax_ID[iPlot][y_] = col->getLy();
      plotMax_ID[iPlot][z_] = col->getLz();
    }else{
      if(myrank==0)cout<<"Unknown plot range!! plotString = "<<plotString<<endl;
      abort();
    }

    // Find out plot variables.
    if(plotString.find("all") !=string::npos){
      // Only include two species.
      plotVar_I[iPlot] = "qS0 qS1 Bx By Bz Ex Ey Ez kXXS0 kYYS0 kZZS0 kXYS0 kXZS0 kYZS0 kXXS1 kYYS1 kZZS1 kXYS1 kXZS1 kYZS1 jxS0 jyS0 jzS0 jxS1 jyS1 jzS1";
      nameSnapshot_I[iPlot] += "_all";
    }else if(plotString.find("var") !=string::npos){
      
      plotVar_I[iPlot] = col->expandVariable(col->getplotVar(iPlot));
      nameSnapshot_I[iPlot] += "_var";
    }else if(plotString.find("fluid") !=string::npos){
      // Only include two species.
      plotVar_I[iPlot] = "rhoS0 rhoS1 Bx By Bz Ex Ey Ez uxS0 uyS0 uzS0 uxS1 uyS1 uzS1 pS0 pS1 pXXS0 pYYS0 pZZS0 pXYS0 pXZS0 pYZS0 pXXS1 pYYS1 pZZS1 pXYS1 pXZS1 pYZS1";
      nameSnapshot_I[iPlot] += "_fluid";
    }else if(plotString.find("particles") !=string::npos){
      doOutputParticles_I[iPlot] = true;
      plotVar_I[iPlot] = "ux uy uz weight"; 
      
      string subString0; 
      pos = plotString.find("particles");
      subString0 = plotString.substr(pos);
      pos = subString0.find_first_of(" \t\n");
      subString0 = subString0.substr(0,pos);
      nameSnapshot_I[iPlot] += "_";
      nameSnapshot_I[iPlot] += subString0;     

      // Find out the output species.
      subString0.erase(0,9);
      stringstream ss0;
      ss0<<subString0<<endl;
      ss0>>iSpeciesOutput_I[iPlot];
      
    }else{
      if(myrank==0)cout<<"Unknown plot variables!! plotString = "<<plotString<<endl;
      abort();
    }

    // Analyze plot variables.
    string::size_type pos1, pos2;
    pos1=0; pos2=0;
    nVar_I[iPlot] = 0;
    int count=0;
    while(pos1 !=string::npos){
      pos1 = plotVar_I[iPlot].find_first_not_of(' ',pos2);
      pos2 = plotVar_I[iPlot].find_first_of(" \t\n",pos1);
      if(pos1 !=string::npos){       	
	Var_II[iPlot][count] = plotVar_I[iPlot].substr(pos1,pos2-pos1);
	//nVar_I[iPlot]++;
	count++;
      }
    }
    nVar_I[iPlot] = count;

    // Find out output format.
    if(plotString.find("ascii") !=string::npos){
      outputFormat_I[iPlot] = "ascii";
    }else if(plotString.find("real4") !=string::npos){
      outputFormat_I[iPlot] = "real4";
    }else if(plotString.find("real8") !=string::npos){
      outputFormat_I[iPlot] = "real8";    
    }else {
      if(myrank==0)cout<<"Unknown plot output format!! plotString = "<<plotString<<endl;
      abort();
    }
    
    // Find out output unit.
    if(plotString.find("si") !=string::npos || plotString.find("SI") !=string::npos){
      outputUnit_I[iPlot] = "SI";
    }else if(plotString.find("pic") !=string::npos || plotString.find("PIC") !=string::npos){
      outputUnit_I[iPlot] = "PIC";
    }else if(plotString.find("planet") !=string::npos || plotString.find("PLANET") !=string::npos){
      outputUnit_I[iPlot] = "PLANETARY";
    }else {
      if(myrank==0)cout<<"Unknown plot output unit!! plotString = "<<plotString<<endl;
      abort();
    }

    find_output_list(iPlot);
        
    if(doTestFunc){
      cout<<" plotstring= "<<plotString<<endl;
      cout<<"length sub = "<<subString.size()
	  <<" length plotstring= "<<plotString.size()<<endl;
      cout<<"iplot = "<<iPlot<<"\n"
	  <<" plotRangeMin_x = "<<plotMin_ID[iPlot][x_]
	  <<" plotRangeMax_x = "<<plotMax_ID[iPlot][x_]<<"\n"
	  <<" plotRangeMin_y = "<<plotMin_ID[iPlot][y_]
	  <<" plotRangeMax_y = "<<plotMax_ID[iPlot][y_]<<"\n"
	  <<" plotRangeMin_z = "<<plotMin_ID[iPlot][z_]
	  <<" plotRangeMax_z = "<<plotMax_ID[iPlot][z_]<<"\n"
	  <<" plotIndexMin_x = "<<plotIdxLocMin_ID[iPlot][x_]
	  <<" plotIndexMax_x = "<<plotIdxLocMax_ID[iPlot][x_]<<"\n"
	  <<" plotIndexMin_y = "<<plotIdxLocMin_ID[iPlot][y_]
	  <<" plotIndexMax_y = "<<plotIdxLocMax_ID[iPlot][y_]<<"\n"
	  <<" plotIndexMin_z = "<<plotIdxLocMin_ID[iPlot][z_]
	  <<" plotIndexMax_z = "<<plotIdxLocMax_ID[iPlot][z_]<<"\n"
	  <<" namesnapshot = "<<nameSnapshot_I[iPlot]
	  <<endl;
      cout<<"doOutputParticles = "<<doOutputParticles_I[iPlot]<<endl;
      if(doOutputParticles_I[iPlot]){
	cout<<"iSpeciesOutput = "<<iSpeciesOutput_I[iPlot]<<endl;
      }
      cout<<"\n plot variables:"<<endl;
      for(int i=0; i<nVar_I[iPlot]; i++){
	cout<<"i= "<<i<<" var= "<<Var_II[iPlot][i]<<endl;
      }
      cout<<"\n output format: "<<outputFormat_I[iPlot]
	  <<"\n output unit: "<<outputUnit_I[iPlot]
	  <<endl;
      if(isSat_I[iPlot]){
	cout<<"satllite input file = "<<satInputFile_I[iPlot]<<endl;
      }
    }      
  }

}


void c_Solver:: write_plot_header(int iPlot, int cycle){
  string nameSub = "write_plot_header";
  bool doTestFunc;
  doTestFunc = do_test_func(nameSub);
  //-------------------

  stringstream ss;
  int time;
  time = getSItime(); // double to int.

  ss<<"_region"<<col->getiRegion()
    <<"_"<<iPlot
    <<"_t"<<setfill('0')<<setw(8)<<col->second_to_clock_time(time)
    <<"_n"<<setfill('0')<<setw(8)<<cycle
    <<".h";
  if(myrank==0){
    string filename;
    filename = nameSnapshot_I[iPlot] +ss.str();
    ofstream outFile;
    outFile.open(filename.c_str(),fstream::out | fstream::trunc);
    outFile<<std::scientific;
    outFile.precision(12);
    outFile<<"#HEADFILE\n";
    outFile<<filename<<"\n";
    outFile<<nprocs<<"\t"<<"nProc\n";
    outFile<<(IsBinary? 'T':'F')<<"\t save_binary\n";
    if(IsBinary)
      nByte = sizeof(double);
      outFile<<nByte<<"\t nByte\n";
    outFile<<"\n";

    outFile<<"#NDIM\n";
    outFile<<col->getnDim()<<"\t nDim\n";
    outFile<<"\n";
    
    outFile<<"#GRIDGEOMETRYLIMIT\n";
    outFile<<"cartesian\n";
    for(int i=0; i<col->getnDim();i++){
      outFile<<0.0<<"\t XyzMin"<<i<<"\n";
      outFile<<col->getFluidLx()<<"\t XyzMax"<<i<<"\n";
    }
    outFile<<"\n";
    
    outFile<<"#NSTEP\n";
    outFile<<cycle<<"\t nStep\n";
    outFile<<"\n";

    outFile<<"#TIMESIMULATION\n";
    outFile<<getSItime()<<"\t TimeSimulation\n";
    outFile<<"\n";

    outFile<<"#PLOTRANGE\n";      
    for(int i=0; i<col->getnDim();i++){
      double x0=0;
      if((doOutputParticles_I[iPlot] || isSat_I[iPlot]) && !col->getdoRotate()){
	// For field output, plotMin_ID is already in MHD coordinates. 
	
	if(i==0) x0 = col->getFluidStartX();
	if(i==1) x0 = col->getFluidStartY();
	if(i==2) x0 = col->getFluidStartZ();
      }
      outFile<<(plotMin_ID[iPlot][i]+x0)*No2OutL<<"\t coord"<<i<<"Min\n";
      outFile<<(plotMax_ID[iPlot][i]+x0)*No2OutL<<"\t coord"<<i<<"Max\n";
    }
    outFile<<"\n";

    int plotDx = col->getplotDx(iPlot);
    if(doOutputParticles_I[iPlot]) plotDx=1;
    outFile<<"#CELLSIZE\n";
    outFile<<plotDx*col->getDx()*No2OutL<<"\t dx\n";
    outFile<<plotDx*col->getDy()*No2OutL<<"\t dy\n";
    outFile<<plotDx*col->getDz()*No2OutL<<"\t dz\n";
    outFile<<"\n";

    outFile<<"#NCELL\n";
    outFile<<nCell_I[iPlot]<<"\t nCell\n";
    outFile<<"\n";
       
    outFile<<"#PLOTRESOLUTION\n";
    for(int i=0; i<col->getnDim();i++){
      if(doOutputParticles_I[iPlot] || isSat_I[iPlot]){
	outFile<<(-1)<<"\t plotDx\n"; // Save partices as unstructured.
      }else{
	outFile<<0<<"\t plotDx\n";
      }
    }                
    outFile<<"\n";


    // me, m1, m2....c, rPlanet
    int nScalar = 2*ns + 2;
    outFile<<"#SCALARPARAM\n";
    outFile<<nScalar<<"\t nParam\n";

    for(int iSpecies=0; iSpecies<ns; iSpecies++){
      outFile<<col->getMiSpecies(iSpecies)<<"\t mS"<<iSpecies<<"\n";
      outFile<<col->getQiSpecies(iSpecies)<<"\t qS"<<iSpecies<<"\n";
    }
    outFile<<col->getcLightSI()<<"\t cLight\n";
    outFile<<col->getrPlanet()<<"\t rPlanet\n";
    outFile<<"\n";

    {
      string scalarVar;
      stringstream ss;
      for(int iSpecies=0; iSpecies<ns; iSpecies++){
	ss<<" mS"<<iSpecies<<" qS"<<iSpecies;
      }
      ss<<" clight"<<" xSI";
      scalarVar = ss.str();

      outFile<<"#PLOTVARIABLE\n";
      outFile<<nVar_I[iPlot]<<"\t nPlotVar\n";
      outFile<<plotVar_I[iPlot]<<scalarVar<<"\n";    
      outFile<<outputUnit_I[iPlot]<<"\n"; 
      outFile<<"\n";
    }

    outFile<<"#OUTPUTFORMAT\n";
    outFile<<outputFormat_I[iPlot]<<"\n";
    outFile<<"\n";
    
    if(outFile.is_open()) outFile.close();
    if(doTestFunc) {
      cout<<nameSub<<" :filename = "<<filename<<endl;      
    }        
  }
}
  

void c_Solver:: write_plot_data(int iPlot, int cycle){
  string nameSub = "write_plot_data";
  bool doTestFunc;
  doTestFunc = do_test_func(nameSub);
  //-------------------
  // For particle output, we already know if it is necessary to write file on
  // this processor, but we do not know how many particles should be saved.
  // MPI_Reduced should be called later to count the total number of output
  // particles. 
  if(!doSaveCellLoc_I[iPlot] && !doOutputParticles_I[iPlot]) return;
  
  string filename;
  stringstream ss;
  int time;
  time = getSItime(); // double to int.
  int nLength;
  if(nprocs>10000){
    nLength=5;
  }else if(nprocs>100000){
    nLength=5;
  }else{
    nLength = 4;
  }
  
  ss<<"_region"<<col->getiRegion()
    <<"_"<<iPlot
    <<"_t"<<setfill('0')<<setw(8)<<col->second_to_clock_time(time)
    <<"_n"<<setfill('0')<<setw(8)<<cycle
    <<"_pe"<<setfill('0')<<setw(nLength)<<myrank
    <<".idl";
  filename = nameSnapshot_I[iPlot] +ss.str();

  if(doOutputParticles_I[iPlot]){
    long nPartOutputLocal;
    nPartOutputLocal = 0;

    if(doSaveCellLoc_I[iPlot]){
      int iSpecies;
      iSpecies = iSpeciesOutput_I[iPlot];
    
      int dnOutput;
      dnOutput = col->getplotDx(iPlot);
      if(dnOutput<1) {
	if(myrank==1) cout<<" Error: dnOutput = "<<dnOutput<<" which should be an positive integer !!!!!!!"<<endl;
	abort();
      }
      part[iSpecies].write_plot_particles(filename,dnOutput,
					  nPartOutputLocal,
					  plotMin_ID[iPlot][x_],
					  plotMax_ID[iPlot][x_],
					  plotMin_ID[iPlot][y_],
					  plotMax_ID[iPlot][y_],
					  plotMin_ID[iPlot][z_],
					  plotMax_ID[iPlot][z_],
					  pointList_IID[iPlot], nPoint_I[iPlot],
					  isSat_I[iPlot],
					  No2OutL, No2OutV
					  );
    }
    MPI_Reduce(&nPartOutputLocal, &nCell_I[iPlot],1,MPI_LONG,MPI_SUM,0,MPI_COMM_MYSIM);

  }else{          
    EMf->write_plot_field(filename, Var_II[iPlot], nVar_I[iPlot],
			  pointList_IID[iPlot], nPoint_I[iPlot], isSat_I[iPlot],
			  No2OutL, No2OutV, No2OutB,
			  No2OutRho, No2OutP, No2OutJ);
  }

}

// Set the values of No2Out.
void c_Solver:: set_output_unit(int iPlot){
  string nameSub = "write_plot_data";
  bool doTestFunc;
  doTestFunc = do_test_func(nameSub);
  //-------------------

  if(outputUnit_I[iPlot]=="SI" || outputUnit_I[iPlot]=="PLANETARY"){
    No2OutL   = col->getNo2SiL();
    No2OutV   = col->getNo2SiV();
    No2OutB   = col->getNo2SiB();
    No2OutRho = col->getNo2SiRho();
    No2OutP   = col->getNo2SiP();
    No2OutJ   = col->getNo2SiJ();

    if(outputUnit_I[iPlot]=="PLANETARY") {
      double massProton = 1.6726219e-27; //unit: kg
      No2OutL   *= 1./col->getrPlanet(); // it should be No2OutL *= 1/rPlanet
      No2OutV   *= 1e-3; // m/s -> km/s
      No2OutB   *= 1e9; // T -> nT
      No2OutRho *=  1./massProton*1e-6; // kg/m^3 -> amu/cm^3
      No2OutP   *= 1e9; // Pa -> nPa
      No2OutJ   *= 1; // ?????????????????????? what should it be??????
    }
  }else if(outputUnit_I[iPlot]=="PIC"){
    No2OutL = 1; No2OutV = 1; No2OutB = 1;
    No2OutRho = 1; No2OutP = 1; No2OutJ = 1; 
  }else{
    if(myrank==0)cout<<"Unknown unit!! unit = "<<outputUnit_I[iPlot]<<endl;
      abort();
  }

  if(doTestFunc){
    cout<<"iPlot= "<<iPlot<<":\n"
	<<"No2OutL = "<<No2OutL<<"\n"
	<<"No2OutV = "<<No2OutV<<"\n"
	<<"No2OutB = "<<No2OutB<<"\n"
	<<"No2OutRho = "<<No2OutRho<<"\n"
	<<"No2OutP = "<<No2OutP<<"\n"
	<<"No2OutJ = "<<No2OutJ
	<<endl;
  }

}


void c_Solver:: find_output_list(int iPlot){
  string nameSub = "find_output_list";
  bool doTestFunc;
  doTestFunc = do_test_func(nameSub);
  //----------------------------------

  if(doTestFunc) cout<<"Start "<<nameSub<<endl;
  int plotDx = col->getplotDx(iPlot);
  
  if(!isSat_I[iPlot]){
    /*
      Find out the node index for output. Only useful for non-satellite field
      output. Also provide useful information for non-satellite particle output,
      eventhough the information has not been used in the current code. 
    */

    /* Assume there are two processors in X-direction.
       
       proc 1 
       _________________
       |   |   |   |   |
       |___|___|___|___|
       |   |   |   |   | 
       |___|___|___|___|
       |   |   |   |   |
       |___|___|___|___|
       0   1   2   3      global node index
         0   1   2        global cell index
       0   1   2   3   4  local node index
         0   1   2   3    local cell index

       proc 2
       _________________
       |   |   |   |   |
       |___|___|___|___|
       |   |   |   |   | 
       |___|___|___|___|
       |   |   |   |   |
       |___|___|___|___|
           3   4   5   6       global node index
             3   4   5         global cell index
       0   1   2   3   4       local node index
         0   1   2   3         local cell index

       In X-directoin, assume the global cell index is 0 - 5, then the 
       global node index is 0 - 6. 

	
       In a global view, cell 0 and 5 are ghost cells. For MHD-IPIC, cell
       1 and 4 are also behave like ghost cells: particles are repopulated
       in cell 1 and 4 when boundary conditions are applied from MHD, and
       electric field solver solve field for nodes from 2 to 4. (all the 
       indexes are global index.)

       In a local view, the cells with local index 0 and 3 are ghost cells. 
       1) Global node 3 is on bothe proc 1 and proc 2. So the information on 
       this node only needs saved once. We choose to save on proc 2 (local
       node index 1), and the local nodes 3 and 4 are not saved. 
       2) If the local node 3 is close to boundary, then save the information.

       So, for this example, nodes with local node index 1 or 2 on proc 1, 
       and nodes with local node index 1, 2 or 3 on proc 2 are saved.        
    */

    // Calcualte plotIdxLoc, which is the local index, based on
    // plot range.

    int ig, jg, kg;
    
    plotIdxLocMin_ID[iPlot][x_]= 30000;
    plotIdxLocMax_ID[iPlot][x_]=-30000;

    int iEnd;
    iEnd = grid->getNXN()-2;
    if(vct->getXright_neighbor()==MPI_PROC_NULL) iEnd++;
    
    for(int i=1; i<iEnd; i++){
      col->getGlobalIndex(i,1,1,&ig,&jg,&kg);

      if(ig % plotDx == 0 &&
	 grid->getXN(i)>=plotMin_ID[iPlot][x_] - 0.5*col->getDx() &&
	 grid->getXN(i)< plotMax_ID[iPlot][x_] + 0.5*col->getDx()){
	if(i<plotIdxLocMin_ID[iPlot][x_]) plotIdxLocMin_ID[iPlot][x_] = i;
	if(i>plotIdxLocMax_ID[iPlot][x_]) plotIdxLocMax_ID[iPlot][x_] = i;
      }
    }

    plotIdxLocMin_ID[iPlot][y_]= 30000;
    plotIdxLocMax_ID[iPlot][y_]=-30000;

    iEnd = grid->getNYN()-2;
    if(vct->getYright_neighbor()==MPI_PROC_NULL) iEnd++;

    for(int i=1; i<iEnd; i++){
      col->getGlobalIndex(1,i,1,&ig,&jg,&kg);

      if(jg % plotDx == 0 &&
	 grid->getYN(i)>=plotMin_ID[iPlot][y_] - 0.5*col->getDy() &&
	 grid->getYN(i)< plotMax_ID[iPlot][y_] + 0.5*col->getDy()){
	if(i<plotIdxLocMin_ID[iPlot][y_]) plotIdxLocMin_ID[iPlot][y_] = i;
	if(i>plotIdxLocMax_ID[iPlot][y_]) plotIdxLocMax_ID[iPlot][y_] = i;
      }
    }
    
    plotIdxLocMin_ID[iPlot][z_]= 30000;
    plotIdxLocMax_ID[iPlot][z_]=-30000;

    iEnd = grid->getNZN()-2;
    if(vct->getZright_neighbor()==MPI_PROC_NULL) iEnd++;

    for(int i=1; i<iEnd; i++){
      col->getGlobalIndex(1,1,i,&ig,&jg,&kg);

      if(kg % plotDx == 0 &&
	 grid->getZN(i)>=plotMin_ID[iPlot][z_] - 0.5*col->getDz() &&
	 grid->getZN(i)< plotMax_ID[iPlot][z_] + 0.5*col->getDz()){
	if(i<plotIdxLocMin_ID[iPlot][z_]) plotIdxLocMin_ID[iPlot][z_] = i;
	if(i>plotIdxLocMax_ID[iPlot][z_]) plotIdxLocMax_ID[iPlot][z_] = i;
      }
    }
    
    if(col->getnDim()==2) {
      // When IPIC3D coupled with MHD, the 2D plane is always XY plane.
      plotIdxLocMin_ID[iPlot][z_] = 1;
      plotIdxLocMax_ID[iPlot][z_] = 1;
    }


    const int minI = plotIdxLocMin_ID[iPlot][x_];
    const int maxI = plotIdxLocMax_ID[iPlot][x_];
    const int minJ = plotIdxLocMin_ID[iPlot][y_];
    const int maxJ = plotIdxLocMax_ID[iPlot][y_];
    const int minK = plotIdxLocMin_ID[iPlot][z_];
    const int maxK = plotIdxLocMax_ID[iPlot][z_];
    
    long nPoint;
    nPoint =
      floor((maxI-minI)/plotDx + 1)*
      floor((maxJ-minJ)/plotDx + 1)*
      floor((maxK-minK)/plotDx + 1);
    if( minI>maxI || minJ>maxJ || minK>maxK) nPoint=0;
    if(nPoint>0){
      doSaveCellLoc_I[iPlot] = true;
    }else{
      nPoint = 0; 
    }
      
    if(!doOutputParticles_I[iPlot]){
      MPI_Reduce(&nPoint, &nCell_I[iPlot],1,MPI_LONG,MPI_SUM,0,MPI_COMM_MYSIM);
      
      nPoint_I[iPlot] = nPoint;
      long iCount = 0; 
      for(int i=minI; i<= maxI; i+=plotDx)
	for(int j=minJ; j<=maxJ; j+=plotDx)
	  for(int k=minK; k<=maxK; k+=plotDx){
	    // pointList_IID stores the index of the output nodes.
	    pointList_IID[iPlot][iCount][0] = i;
	    pointList_IID[iPlot][iCount][1] = j;
	    pointList_IID[iPlot][iCount][2] = k;
	    iCount++;
	  }	
    }
      
  }else{
    double plotRange_I[6];
    col->read_satellite_file(satInputFile_I[iPlot]);
    // pointList_IID stores the coordinate (x/y/z) of the output points.
    col->find_sat_points(pointList_IID[iPlot], nPoint_I[iPlot],
			 nNodeMax,plotRange_I,
			 grid->getXstart(), grid->getXend(),
			 grid->getYstart(), grid->getYend(),
			 grid->getZstart(), grid->getZend());
    MPI_Reduce(&nPoint_I[iPlot], &nCell_I[iPlot],1,MPI_LONG,MPI_SUM,0,MPI_COMM_MYSIM);
    if(nPoint_I[iPlot]>0) doSaveCellLoc_I[iPlot] = true;

    if(nCell_I[iPlot]>0){
      double drSat = col->getSatRadius(); 

      // Find out a cube can contain all the satellite sampling points. 
      plotMin_ID[iPlot][x_] = plotRange_I[0] - drSat;
      plotMax_ID[iPlot][x_] = plotRange_I[1] + drSat;
      plotMin_ID[iPlot][y_] = plotRange_I[2] - drSat;
      plotMax_ID[iPlot][y_] = plotRange_I[3] + drSat;
      plotMin_ID[iPlot][z_] = plotRange_I[4] - drSat;
      plotMax_ID[iPlot][z_] = plotRange_I[5] + drSat;
      
    }
    
  }// if(isSat_I)
    
  // Do not correct plot range for 'particles' now. Because the position of
  // particle does not depend on grid. But plotIdxLoc may be useful.
  // It can give us some feelings about where the output particles are. 
  if(!doOutputParticles_I[iPlot] && !isSat_I[iPlot]){
    // Correct PlotRange based on plotIdxLoc-----begin
           
    double xMinL_I[nDimMax], xMaxL_I[nDimMax],
      xMinG_I[nDimMax], xMaxG_I[nDimMax];

    // x
    if(plotIdxLocMax_ID[iPlot][x_]>=plotIdxLocMin_ID[iPlot][x_]){
      xMinL_I[0] = grid->getXN(plotIdxLocMin_ID[iPlot][x_]);
      xMaxL_I[0] = grid->getXN(plotIdxLocMax_ID[iPlot][x_]);
    }else{
      // This processor does not output any node.
      xMinL_I[0] = 2*col->getLx();
      xMaxL_I[0] = -1;
    }

    // y
    if(plotIdxLocMax_ID[iPlot][y_]>=plotIdxLocMin_ID[iPlot][y_]){
      xMinL_I[1] = grid->getYN(plotIdxLocMin_ID[iPlot][y_]);
      xMaxL_I[1] = grid->getYN(plotIdxLocMax_ID[iPlot][y_]);
    }else{
      // This processor does not output any node.
      xMinL_I[1] = 2*col->getLy();
      xMaxL_I[1] = -1;
    }

    // z
    if(plotIdxLocMax_ID[iPlot][z_]>=plotIdxLocMin_ID[iPlot][z_]){
      xMinL_I[2] = grid->getZN(plotIdxLocMin_ID[iPlot][z_]);
      xMaxL_I[2] = grid->getZN(plotIdxLocMax_ID[iPlot][z_]);
    }else{
      // This processor does not output any node.
      xMinL_I[2] = 2*col->getLz();
      xMaxL_I[2] = -1;
    }
      
    MPI_Reduce(xMinL_I, xMinG_I,nDimMax,MPI_DOUBLE,MPI_MIN,0,MPI_COMM_MYSIM);
    MPI_Reduce(xMaxL_I, xMaxG_I,nDimMax,MPI_DOUBLE,MPI_MAX,0,MPI_COMM_MYSIM);


    // Change plotRange into MHD coordinates. The field outputs are also
    // in MHD coordinates, see EMfields3D.cpp:write_plot_field().
    if(col->getdoRotate()){
      plotMin_ID[iPlot][x_] = xMinG_I[0] - 0.4*col->getDx()*plotDx;
      plotMax_ID[iPlot][x_] = xMaxG_I[0] + 0.4*col->getDx()*plotDx;
      plotMin_ID[iPlot][y_] = xMinG_I[1] - 0.4*col->getDy()*plotDx;
      plotMax_ID[iPlot][y_] = xMaxG_I[1] + 0.4*col->getDy()*plotDx;
      plotMin_ID[iPlot][z_] = xMinG_I[2] - 0.4*col->getDz()*plotDx;
      plotMax_ID[iPlot][z_] = xMaxG_I[2] + 0.4*col->getDz()*plotDx;
    }else{
      plotMin_ID[iPlot][x_] = xMinG_I[0] - 0.4*col->getDx()*plotDx + col->getFluidStartX();
      plotMax_ID[iPlot][x_] = xMaxG_I[0] + 0.4*col->getDx()*plotDx + col->getFluidStartX();
      plotMin_ID[iPlot][y_] = xMinG_I[1] - 0.4*col->getDy()*plotDx + col->getFluidStartY();
      plotMax_ID[iPlot][y_] = xMaxG_I[1] + 0.4*col->getDy()*plotDx + col->getFluidStartY();
      plotMin_ID[iPlot][z_] = xMinG_I[2] - 0.4*col->getDz()*plotDx + col->getFluidStartZ();
      plotMax_ID[iPlot][z_] = xMaxG_I[2] + 0.4*col->getDz()*plotDx + col->getFluidStartZ();
    }
      
    // Correct PlotRange based on plotIdxLoc-----end
  }    

}


void c_Solver::EM_MaxwellImage(double *vecIn, double *vecOut, int n){
  bool doSolveForChange = true;
  EMf->MaxwellImage(vecOut, vecIn, doSolveForChange);
}

void c_Solver::EM_PoissonImage(double *vecIn, double *vecOut, int n){
  bool doSolveForChange = true;
  EMf->PoissonImage(vecOut, vecIn, doSolveForChange);
}

void c_Solver::EM_matvec_weight_correction(double *vecIn, double *vecOut, int n){
  EMf->matvec_weight_correction(vecOut, vecIn);
}

#endif
