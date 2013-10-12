!  Copyright (C) 2002 Regents of the University of Michigan, portions used with permission 
!  For more information, see http://csem.engin.umich.edu/tools/swmf
subroutine OH_set_buffer_grid(DD)
  use OH_ModBuffer,ONLY:&
       set_spher_buffer_grid,set_buffer_name,&
       DomainDecompositionType,&
       LocalBufferDD
  use CON_coupler,ONLY:IH_,OH_,is_proc
  implicit none
  type(DomainDecompositionType),&
       intent(out)::DD

  call set_spher_buffer_grid(&
       DD,OH_,IsLocal=.false.)
  if(.not.is_proc(OH_))return

  call set_spher_buffer_grid(&
       LocalBufferDD,OH_,IsLocal=.true.)
  call set_buffer_name('OH_from_ih',IH_)

end subroutine OH_set_buffer_grid
