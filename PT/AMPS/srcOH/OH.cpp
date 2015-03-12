#include "OH.h"


// OUTPUT -----------------------------------------------------------------------------------
int OH::Output::TotalDataLength = 0; 
int OH::Output::ohSourceDensityOffset =-1; 
int OH::Output::ohSourceMomentumOffset=-1;
int OH::Output::ohSourceEnergyOffset  =-1;


void OH::Output::PrintVariableList(FILE* fout,int DataSetNumber) {
  fprintf(fout,",\"ohSourceDensity\",\"ohSourceMomentum\",\"ohSourceEnergy\"");
}

void OH::Output::Interpolate(PIC::Mesh::cDataCenterNode** InterpolationList,double *InterpolationCoeficients,int nInterpolationCoeficients,PIC::Mesh::cDataCenterNode *CenterNode){

  double S1=0.0, S2=0.0, S3=0.0;
  int i,idim;
  char *SamplingBuffer;

  for (i=0;i<nInterpolationCoeficients;i++) {

    S1+=(*((double*)(InterpolationList[i]->GetAssociatedDataBufferPointer()+OH::Output::ohSourceDensityOffset)))*InterpolationCoeficients[i];

    S2+=(*((double*)(InterpolationList[i]->GetAssociatedDataBufferPointer()+OH::Output::ohSourceMomentumOffset)))*InterpolationCoeficients[i];

    S3+=(*((double*)(InterpolationList[i]->GetAssociatedDataBufferPointer()+OH::Output::ohSourceEnergyOffset)))*InterpolationCoeficients[i];
  }

  memcpy(CenterNode->GetAssociatedDataBufferPointer()+OH::Output::ohSourceDensityOffset,&S1,sizeof(double));
  memcpy(CenterNode->GetAssociatedDataBufferPointer()+OH::Output::ohSourceMomentumOffset,&S2,sizeof(double));
  memcpy(CenterNode->GetAssociatedDataBufferPointer()+OH::Output::ohSourceEnergyOffset,&S3,sizeof(double));

}

void OH::Output::PrintData(FILE* fout,int DataSetNumber,CMPI_channel *pipe,int CenterNodeThread,PIC::Mesh::cDataCenterNode *CenterNode){
  double t;

  //SourceDensity
  if (pipe->ThisThread==CenterNodeThread) {
    t= *((double*)(CenterNode->GetAssociatedDataBufferPointer()+OH::Output::ohSourceDensityOffset));
  }

  if (pipe->ThisThread==0) {
    if (CenterNodeThread!=0) pipe->recv(t,CenterNodeThread);

    fprintf(fout,"%e ",t);
  }
  else pipe->send(t);

  //SourceMomentum
  if (pipe->ThisThread==CenterNodeThread) {
    t= *((double*)(CenterNode->GetAssociatedDataBufferPointer()+OH::Output::ohSourceMomentumOffset));
  }

  if (pipe->ThisThread==0) {
    if (CenterNodeThread!=0) pipe->recv(t,CenterNodeThread);

    fprintf(fout,"%e ",t);
  }
  else pipe->send(t);

  //SourceDensity
  if (pipe->ThisThread==CenterNodeThread) {
    t= *((double*)(CenterNode->GetAssociatedDataBufferPointer()+OH::Output::ohSourceEnergyOffset));
  }

  if (pipe->ThisThread==0) {
    if (CenterNodeThread!=0) pipe->recv(t,CenterNodeThread);

    fprintf(fout,"%e ",t);
  }
  else pipe->send(t);

}

int OH::Output::RequestDataBuffer(int offset){
  OH::Output::ohSourceDensityOffset=offset;
  OH::Output::TotalDataLength = 1;

  OH::Output::ohSourceMomentumOffset=offset;
  OH::Output::TotalDataLength++;

  OH::Output::ohSourceEnergyOffset=offset;
  OH::Output::TotalDataLength++;

  return OH::Output::TotalDataLength*sizeof(double);
}


void OH::Output::Init() {
  //request sampling buffer and particle fields
  PIC::IndividualModelSampling::RequestStaticCellData.push_back(OH::Output::RequestDataBuffer);

  //print out of the otuput file
  PIC::Mesh::PrintVariableListCenterNode.push_back(OH::Output::PrintVariableList);
  PIC::Mesh::PrintDataCenterNode.push_back(OH::Output::PrintData);
  PIC::Mesh::InterpolateCenterNode.push_back(OH::Output::Interpolate);
}


// Loss -------------------------------------------------------------------------------------

double OH::Loss::LifeTime(double *x, int spec, long int ptr,bool &PhotolyticReactionAllowedFlag,cTreeNodeAMR<PIC::Mesh::cDataBlockAMR> *node){

  long int nd;
  int i,j,k;
  double PlasmaBulkVelocity[3];

  double lifetime=0.0;

  nd=PIC::Mesh::mesh.fingCellIndex(x,i,j,k,node);
  //  PIC::CPLR::GetBackgroundPlasmaVelocity(PlasmaBulkVelocity,x,nd,node);

  PhotolyticReactionAllowedFlag=true;

  // the model has hydrogen only
  if (spec!=_H_SPEC_) {
    PhotolyticReactionAllowedFlag=false;
    return -1.0;
  }

  switch (spec) {
  case _H_SPEC_:
  lifetime=1E8;// / ChargeExchange::LifeTime(_H_SPEC_, v1, v2, Temp, NDen);
    break;
  default:
    exit(__LINE__,__FILE__,"Error: unknown specie");
  }

  return lifetime;

}

int OH::Loss::ReactionProcessor(double *xInit,double *xFinal,double *vFinal,long int ptr,int &spec,PIC::ParticleBuffer::byte *ParticleData, cTreeNodeAMR<PIC::Mesh::cDataBlockAMR>* node){

  int *ReactionProductsList,nReactionProducts;
  double *ReactionProductVelocity;
  int ReactionChannel;
  bool PhotolyticReactionRoute;
  /*
  PhotolyticReactionRoute=(rnd()<PhotolyticReactionRate/(PhotolyticReactionRate+ElectronImpactRate)) ? true : false;

  if (PhotolyticReactionRoute==true) {
    PhotolyticReactions::GenerateReactionProducts(spec,ReactionChannel,nReactionProducts,ReactionProductsList,ReactionProductVelocity);
  }
  else {
    ElectronImpact::GenerateReactionProducts(spec,ElectronTemeprature,ReactionChannel,nReactionProducts,ReactionProductsList,ReactionProductVelocity);
  }

  //inject the products of the reaction
  double ParentTimeStep,ParentParticleWeight;

#if  _SIMULATION_PARTICLE_WEIGHT_MODE_ == _SPECIES_DEPENDENT_GLOBAL_PARTICLE_WEIGHT_
  ParentParticleWeight=PIC::ParticleWeightTimeStep::GlobalParticleWeight[spec];
#else
  ParentParticleWeight=0.0;
  exit(__LINE__,__FILE__,"Error: the weight mode is node defined");
#endif

#if _SIMULATION_TIME_STEP_MODE_ == _SPECIES_DEPENDENT_GLOBAL_TIME_STEP_
  ParentTimeStep=PIC::ParticleWeightTimeStep::GlobalTimeStep[spec];
#else
  ParentTimeStep=0.0;
  exit(__LINE__,__FILE__,"Error: the time step node is not defined");
#endif


  //account for the parent particle correction factor
  ParentParticleWeight*=PIC::ParticleBuffer::GetIndividualStatWeightCorrection(ParticleData);

  //the particle buffer used to set-up the new particle data
  char tempParticleData[PIC::ParticleBuffer::ParticleDataLength];
  PIC::ParticleBuffer::SetParticleAllocated((PIC::ParticleBuffer::byte*)tempParticleData);

  //copy the state of the initial parent particle into the new-daugher particle (just in case....)
  PIC::ParticleBuffer::CloneParticle((PIC::ParticleBuffer::byte*)tempParticleData,ParticleData);

  for (int iProduct=0;iProduct<nReactionProducts;iProduct++) {
    double ProductTimeStep,ProductParticleWeight;
    double ModelParticleInjectionRate,TimeCounter=0.0,TimeIncrement,ProductWeightCorrection=1.0;
    int nInjectedParticles=0,specProduct=ReactionProductsList[iProduct];
    long int newParticle;
    PIC::ParticleBuffer::byte *newParticleData;


#if  _SIMULATION_PARTICLE_WEIGHT_MODE_ == _SPECIES_DEPENDENT_GLOBAL_PARTICLE_WEIGHT_
     ProductParticleWeight=PIC::ParticleWeightTimeStep::GlobalParticleWeight[specProduct];
#else
     ProductParticleWeight=0.0;
     exit(__LINE__,__FILE__,"Error: the weight mode is node defined");
#endif

#if _SIMULATION_TIME_STEP_MODE_ == _SPECIES_DEPENDENT_GLOBAL_TIME_STEP_
     ProductTimeStep=PIC::ParticleWeightTimeStep::GlobalTimeStep[specProduct];
#else
     ProductTimeStep=0.0;
     exit(__LINE__,__FILE__,"Error: the time step node is not defined");
#endif

     ModelParticleInjectionRate=ParentParticleWeight/ParentTimeStep/ProductParticleWeight;

     //inject the product particles
     TimeIncrement+=-log(rnd())/ModelParticleInjectionRate *rnd(); //<- *rnd() is to account for the injection of the first particle in the curent interaction

     while (TimeCounter+TimeIncrement<ProductTimeStep) {
       TimeCounter+=TimeIncrement;
       TimeIncrement+=-log(rnd())/ModelParticleInjectionRate;

       //determine the velocity of the product specie
       double ProductParticleVelocity[3];

       for (int idim=0;idim<3;idim++) ProductParticleVelocity[idim]=vFinal[idim]+ReactionProductVelocity[idim+3*iProduct];

       //generate a particle
       PIC::ParticleBuffer::SetX(xFinal,(PIC::ParticleBuffer::byte*)tempParticleData);
       PIC::ParticleBuffer::SetV(ProductParticleVelocity,(PIC::ParticleBuffer::byte*)tempParticleData);
       PIC::ParticleBuffer::SetI(specProduct,(PIC::ParticleBuffer::byte*)tempParticleData);

       #if _INDIVIDUAL_PARTICLE_WEIGHT_MODE_ == _INDIVIDUAL_PARTICLE_WEIGHT_ON_
       PIC::ParticleBuffer::SetIndividualStatWeightCorrection(ProductWeightCorrection,(PIC::ParticleBuffer::byte*)tempParticleData);
       #endif

       //apply condition of tracking the particle
       #if _PIC_PARTICLE_TRACKER_MODE_ == _PIC_MODE_ON_
       PIC::ParticleTracker::InitParticleID(tempParticleData);
       PIC::ParticleTracker::ApplyTrajectoryTrackingCondition(xInit,xFinal,spec,tempParticleData);
       #endif


       //get and injection into the system the new model particle
       newParticle=PIC::ParticleBuffer::GetNewParticle();
       newParticleData=PIC::ParticleBuffer::GetParticleDataPointer(newParticle);
       memcpy((void*)newParticleData,(void*)tempParticleData,PIC::ParticleBuffer::ParticleDataLength);

       _PIC_PARTICLE_MOVER__MOVE_PARTICLE_BOUNDARY_INJECTION_(newParticle,ProductTimeStep-TimeCounter,node,true);

       //when another particle is injected -> generate new velocity vector
       if (TimeCounter+TimeIncrement<ProductTimeStep) {
         if (PhotolyticReactionRoute==true) {
           PhotolyticReactions::GenerateReactionProducts(spec,ReactionChannel,nReactionProducts,ReactionProductsList,ReactionProductVelocity);
         }
         else {
           ElectronImpact::GenerateReactionProducts(spec,ElectronTemeprature,ReactionChannel,nReactionProducts,ReactionProductsList,ReactionProductVelocity);
         }
       }

     }

  }
  */

  return _PHOTOLYTIC_REACTIONS_PARTICLE_REMOVED_;

}


void OH::Init_BeforeParser(){
  Exosphere::Init_BeforeParser();
  OH::Output::Init();
}


//-----------------------------------------------------------------------------
//substitutes for Exosphere functions

//calcualte the true anomaly angle
double Exosphere::OrbitalMotion::GetTAA(SpiceDouble et) {
  return 0.0;
}

int Exosphere::ColumnIntegral::GetVariableList(char *vlist) {
  int spec,nVariables=0;

  //column density
  for (spec=0;spec<PIC::nTotalSpecies;spec++) {
    if (vlist!=NULL) sprintf(vlist,"%s,  \"Column Integral(%s)\"",vlist,PIC::MolecularData::GetChemSymbol(spec));
    nVariables+=1;
  }

  return nVariables;
}

void Exosphere::ColumnIntegral::CoulumnDensityIntegrant(double *res,int resLength,double* x,cTreeNodeAMR<PIC::Mesh::cDataBlockAMR>* node) {
  int i,j,k,nd,cnt=0,spec;
  double NumberDensity;


  nd=PIC::Mesh::mesh.fingCellIndex(x,i,j,k,node);
  for (i=0;i<resLength;i++) res[i]=0.0;

  for (spec=0;spec<PIC::nTotalSpecies;spec++) {
    //get the local density number
    NumberDensity=node->block->GetCenterNode(nd)->GetNumberDensity(spec);
    res[cnt++]=NumberDensity;
    //    res[cnt++]=NumberDensity*node->block->GetCenterNode(nd)->GetMeanParticleSpeed(spec);
  }


  if (cnt!=resLength) exit(__LINE__,__FILE__,"Error: the length of the vector is not coinsistent with the number of integrated variables");
}

void Exosphere::ColumnIntegral::ProcessColumnIntegrationVector(double *res,int resLength) {
  //do nothing
}

double Exosphere::SurfaceInteraction::StickingProbability(int spec,double& ReemissionParticleFraction,double Temp) {
  ReemissionParticleFraction=0.0;

  return 1.0;
}


double Exosphere::GetSurfaceTemeprature(double cosSubsolarAngle,double *x_LOCAL_SO_OBJECT) {


  return 100.0;
}
