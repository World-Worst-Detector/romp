!************************************************************************
!  This program is part of the
!        OpenMP Source Code Repository
!
!        http://www.pcg.ull.es/ompscr/
!        e-mail: ompscr@etsii.ull.es
!
!   Copyright (c) 2004, OmpSCR Group
!   All rights reserved.
!
!   Redistribution and use in source and binary forms, with or without modification, 
!   are permitted provided that the following conditions are met:
!     * Redistributions of source code must retain the above copyright notice, 
!       this list of conditions and the following disclaimer. 
!     * Redistributions in binary form must reproduce the above copyright notice, 
!       this list of conditions and the following disclaimer in the documentation 
!       and/or other materials provided with the distribution. 
!     * Neither the name of the University of La Laguna nor the names of its contributors 
!       may be used to endorse or promote products derived from this software without 
!       specific prior written permission. 
!
!   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
!   AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
!   WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
!   IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
!   INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
!   BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, 
!   OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
!   WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
!   ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY 
!   OF SUCH DAMAGE.
!
!  FILE:              f_jacobi01.f90
!  VERSION:           1.1
!  DATE:              Oct 2004
!  AUTHORS:           Author:       Joseph Robicheaux, Kuck and Associates, Inc. (KAI), 1998
!                     Modified:     Sanjiv Shah,       Kuck and Associates, Inc. (KAI), 1998
!                     This version: Dieter an Mey,     Aachen University (RWTH), 1999 - 2003
!                                   anmey@rz.rwth-aachen.de
!                                   http://www.rwth-aachen.de/People/D.an.Mey.html
!  COMMENTS TO:       ompscr@etsii.ull.es
!  DESCRIPTION:       program to solve a finite difference discretization of Helmholtz equation : 
!                     (d2/dx2)u + (d2/dy2)u - alpha u = f using Jacobi iterative method.
!  COMMENTS:          OpenMP version 1: two parallel regions with one parallel loop each, the naive approach
!                     Directives are used in this code to achieve paralleism. 
!                     All do loops are parallized with default 'static' scheduling.
!  REFERENCES:        http://www.rz.rwth-aachen.de/computing/hpc/prog/par/openmp/jacobi.html
!  BASIC PRAGMAS:     parallel do
!  USAGE:             ./f_jacobi01.par 1000 1000 0.8 1.0 1000
!  INPUT:             n - grid dimension in x direction
!                     m - grid dimension in y direction
!                     alpha - Helmholtz constant (always greater than 0.0)
!                     tol   - error tolerance for iterative solver
!                     relax - Successice over relaxation parameter
!                     mits  - Maximum iterations for iterative solver
!  OUTPUT:            Residual and error 
!                     u(n,m) - Dependent variable (solutions)
!                     f(n,m) - Right hand side function 
!  FILE FORMATS:      -
!  RESTRICTIONS:      An excesive grid dimension might cause a runtime error
!                     if memory is not enough.
!  REVISION HISTORY:
!**************************************************************************



      program main 
      USE oscrCommon_f
      USE omp_lib
      implicit none 

integer, parameter  :: NUM_ARGS      = 6
integer, parameter  :: NUM_TIMERS    = 1

      integer n,m,mits, kreps,nreps
      double precision tol,relax,alpha 
      integer nthreads, minthreads, maxthreads

      common /idat/ n,m,mits
      common /fdat/ tol,alpha,relax
! 
! Read info 
! 
      character(len=38),dimension(NUM_ARGS) :: argNames = (/'Grid dimension: X dir =               ', &
                                                            'Grid dimension: Y dir =               ', &
                                                            'Helmhotlz constant =                  ', &
                                                            'Successive over-relaxation parameter =', &
                                                            'error tolerance for iterative solver =', &
                                                            'Maximum iterations for solver =       '/)
      character(len=4),dimension(NUM_ARGS) :: defaultValues = (/ '1000', '1000', '0.8 ', '1.0 ', '1e-7', '1000'/)
      character(len=8),dimension(NUM_TIMERS) :: timerNames = (/ 'EXE_TIME' /)

      nthreads = omp_get_max_threads()
      call OSCR_init( nthreads,                                              &
             "Jacobi solver for the Helmholtz equation.",                    &
             '',                                                             &
             NUM_ARGS,                                                       &
             argNames,                                                       &
             defaultValues,                                                  &
             NUM_TIMERS,                                                     &
             NUM_TIMERS,                                                     &
             timerNames )

! 1. GET PARAMETERS
      n = OSCR_getarg_integer(1)
      m = OSCR_getarg_integer(2)
      alpha = OSCR_getarg_doubleprecision(3)
      relax = OSCR_getarg_doubleprecision(4)
      tol = OSCR_getarg_doubleprecision(5)
      mits = OSCR_getarg_integer(6)

!
! Calls a driver routine 
! 
      call driver

      stop
      end 

      subroutine driver
!************************************************************
! Subroutine driver () 
! This is where the arrays are allocated and initialzed. 
!
! Working varaibles/arrays 
!     dx  - grid spacing in x direction 
!     dy  - grid spacing in y direction 
!************************************************************
      
      USE oscrCommon_f
      implicit none 

      integer n,m,mits 
      double precision tol,relax,alpha, dt

      common /idat/ n,m,mits
      common /fdat/tol,alpha,relax

      double precision u(n,m),f(n,m),dx,dy
      double precision mflops, maxmflops

! Initialize data

      call initialize (n,m,alpha,dx,dy,u,f)

! Solve Helmholtz equation

      call OSCR_timer_start(1)
      call jacobi (n,m,dx,dy,alpha,relax,u,f,tol,mits)
      call OSCR_timer_stop(1)
      dt = OSCR_timer_read(1)
      call OSCR_report() 

      mflops = float(mits)*float(m-2)*float(n-2)*13.0d0*0.000001d0 / dt
      write (*,'(a,f12.6)') 'elapsed time usage', dt
      write (*,'(a,f12.6)') 'MFlop/s            ', mflops
     
! Check error between exact solution

      call error_check (n,m,alpha,dx,dy,u,f)

      return 
      end 

      subroutine initialize (n,m,alpha,dx,dy,u,f) 
!*****************************************************
! Initializes data 
! Assumes exact solution is u(x,y) = (1-x^2)*(1-y^2)
!
!*****************************************************
      implicit none 
     
      integer n,m
      double precision u(n,m),f(n,m),dx,dy,alpha
      
      integer i,j, xx,yy
      double precision PI 
      parameter (PI=3.1415926)

      dx = 2.0 / (n-1)
      dy = 2.0 / (m-1)

! Initilize initial condition and RHS

!$omp parallel do private(xx,yy,i,j)
      do j = 1,m
         do i = 1,n
            xx = -1.0 + dx * dble(i-1)        ! -1 < x < 1
            yy = -1.0 + dy * dble(j-1)        ! -1 < y < 1
            u(i,j) = 0.0 
            f(i,j) = -alpha *(1.0-xx*xx)*(1.0-yy*yy) &
     &           - 2.0*(1.0-xx*xx)-2.0*(1.0-yy*yy)
         enddo
      enddo


      return 
      end 

      subroutine error_check (n,m,alpha,dx,dy,u,f) 
      implicit none 
!***********************************************************
! Checks error between numerical and exact solution 
!
!*********************************************************** 
     
      integer n,m
      double precision u(n,m),f(n,m),dx,dy,alpha 
      
      integer i,j
      double precision xx,yy,temp,error 

      dx = 2.0 / (n-1)
      dy = 2.0 / (m-1)
      error = 0.0 

!$omp parallel do private(xx,yy,i,j,temp) reduction(+:error)
      do j = 1,m
         do i = 1,n
            xx = -1.0d0 + dx * dble(i-1)
            yy = -1.0d0 + dy * dble(j-1)
            temp  = u(i,j) - (1.0-xx*xx)*(1.0-yy*yy)
            error = error + temp*temp 
         enddo
      enddo

      error = sqrt(error)/dble(n*m)

      print *, 'Solution Error : ',error

      return 
      end 


      subroutine jacobi (n,m,dx,dy,alpha,omega,u,f,tol,maxit)

      implicit none 
      integer n,m,maxit
      double precision dx,dy,f(n,m),u(n,m),alpha, tol,omega

      integer i,j,k,k_local 
      double precision error,resid,rsum,ax,ay,b
      double precision error_local, uold(n,m)

      real ta,tb,tc,td,te,ta1,ta2,tb1,tb2,tc1,tc2,td1,td2
      real te1,te2

      ax = 1.0/(dx*dx) ! X-direction coef 
      ay = 1.0/(dy*dy) ! Y-direction coef
      b  = -2.0/(dx*dx)-2.0/(dy*dy) - alpha ! Central coeff  

      error = 10.0 * tol 

      k = 1

      do while (k.le.maxit .and. error.gt. tol) 

         error = 0.0    

!$omp parallel do 
         do j=1,m
            do i=1,n
               uold(i,j) = u(i,j) 
            enddo
         enddo
!$omp end parallel do

!$omp parallel do private(resid) reduction(+:error)
         do j = 2,m-1
            do i = 2,n-1 
               resid = (ax*(uold(i-1,j) + uold(i+1,j)) &
     &                + ay*(uold(i,j-1) + uold(i,j+1)) &
     &                 + b * uold(i,j) - f(i,j))/b
               u(i,j) = uold(i,j) - omega * resid
               error = error + resid*resid 
            end do
         enddo
!$omp end parallel do

         k = k + 1
         error = sqrt(error)/dble(n*m)

      enddo                     ! End iteration loop
      
      print *, 'Total Number of Iterations ', k 
      print *, 'Residual                   ', error 

      return 
      end 
