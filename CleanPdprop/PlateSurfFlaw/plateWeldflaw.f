C  plateWeldflaw.f   vers. 3.10   Notched Spec Crack Prop.  FAC oct.26 2013
      SAVE
C  Push-Down List crack prop. program. Semi-ellip. crack on surf near weld.
C  Compile:  gfortran  -g -w -fbounds-check plateWeldflaw.f  -o plateWeldflaw
C  Usage:   plateWeldflaw  scaleFactor <loadHistory >outputFile
C           also writes #crk= data to file    fadInput.rand 
C           (program will not overwrite previous copies of  fadInput.rand )

C  The program is made availble to help students develop advances in crack
C  propagation software.
C  Program based on program "RCROK" Conle 1979 PhD thesis pg.128

C  Copyright (C) 2012  Al Conle
C This file is free software; you can redistribute it and/or modify
C it under the terms of the GNU General Public License as published by
C the Free Software Foundation; either version 2 of the license, or (at
C your option) any later version.
C  This  file is distributed in the hope that it will be useful, but
C WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTA-
C BILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
C License for more details.
C  You should have received a copy of the GNU General PUblic License along
C with this program; if not, write to the Free Software Foundation, Inc.,
C 59 Temple Place -Suite 330, Boston, MA 02111-1307, USA. Try also their
C web site: http://www.gnu.org/copyleft/gpl.html
C Note that some subroutines included in this work are from GNU GPL licenced
C program:  http://fde.uwaterloo.ca/Fde/Calcs/saefcalc1.html

C vers. 3.10 Replace getPeakLoads() s/r  to remove small cycles Oct 26 2013
C            and align the end and begining of points in the history block.
C            Also introduce (but not yet use) a cycle repetition factor.
C            This latter requires a small change in hist. plot of makereport1
C vers. 3.06 Fix error of double damage count near line 2014.  Jul.15 2013
C            Make all "stop" 's   go to 9000 (to close fadInput.rand file)
C vers. 3.05 Correct error of Calculating  lobj00.  (used wrong "c" value
C            in previous versions. (BIG error)   Jul07 2013
C vers. 3.03 change "a" and "c" accumulators to  REAL*8
C            Add output of crack info to a binary file.      Jul01 2013
C            Binary file write for  FAD  post processing.
C vers. 2.30 Add Pm  and Pb  stress to the #crk= line printout Jun26 2013
C vers. 2.24 Activate SAVELEVEL code to reduce output.  Mar10 2013
C vers. 2.23 In s/r getPeakLoads() print out "Filtered" when no changes.
C            to allow makereport1's grep  to function properly  Feb28 2013
C vers. 2.22 Add s/r subCutTail()   not used yet.  Feb3 2013
C vers. 2.21 Correct material file name error  Jan 6 2013
C vers. 2.2  Fixed typo #ACTIVATE_MkmMkb= near line 450. : 
C            caused inactive Mkm,Mkb,  Jan03 2013
C            Fix maxmkdatarow maxmkdatacol specifications.
C vers. 2.1  Correction: multipy Y(sigma) by sqrt(pi*a)
C vers. 2.0  Discretize lobj00, ldo00 lobj90,ldo90, dld00,dld90
C vers. 1.1  Divide damage or dadn  by 2.0 to make it per 1/2 cycle.
C            Add output for loads to be rainflow counted and used for
C            crack initiation analysis.
C vers. 1.00 runs ok.  
C vers. 0.91 Remove the old unused functions
C vers. 0.9 Fork: plateWeldflaw.f and plateWeldflaw+ss.f
C           In this version we have eliminated the local stress-strain stuff.
C           Thus it does the memory thing using deltaK00 and deltaK90 with no
C           tracking of the local ss.  Nov.17 2012
C           Local ss stuff is commented out with "Css"
C vers. 0.8 Create two parallel push-down lists. One for 00 and one for 90 deg.
C           crack tip.  Each has its own deltaK, stress, strain etc.
C           Each is P.D. list counted using its deltaK.
C vers. 0.6 replace Mkm and Mkb read s/r's. Add getMm and getMk s/r's.
C              (extract from testgetMmMkm.f test prog.)
C       Add fw  read and interpolate s/r. subr_getfw.f -> fwSurfFlaw()
C       Add peak pick  s/r. getPeakLoads()
C       Add getStress2Strain(), getLoad2StressStrain()
C       De-activate old functions from thesis version: XKP(),SMITH(),FLD(),DET()
C vers. 0.5 places read and interpolation for Mkm and Mkb into S/Rs. 
C           also adds read and interp. for Mm  and Mb


C In general:
C  1. Counts using Nominal "Load" = deltaK = fn{stsm(),stsb(),a,c,L...}
C  2. Computes Epsilon from Load.   ( not in this version) 
C  3. Computes Sigma from Epsilon   ( not in this version)
C  4. Computed damage as crack length

C  Material behaviour is stabilized.  No cyclic mean stress relaxation
C  or cyclic hardening or softening is performed in this version.  
C  Also no "disappearing" memory of prior deformation due to crack prop. is done.

C  Explanation of primary variables used=
C    tlimL, climL = 1 dimensional arrays of vectors containing
C       the push-ddown list loads.  TLIML is the tensile, CLIML is compr.
C  tlstr, clstr = the p.d. list associated Tens and Compr. strains
C  tlsts, clsts =               "          "               stresses
C  tldam, cldam =               "          "               1/2 cycle fat. damage
C  tlCracklength(), clCracklength() = the crack length when these occurred
C                   will be use to "disappear" memory events due to crack prop.
C  nptt,nptc =  push-down list pointers.
C  lorg, eorg, sorg  The load, strain, stress origin of a given 1/2 cycle
C  lobj, eobj, sobj         "           "      end point        "    "
C  dld, de,ds  =     the change in "    "  during a 1/2 cycle
C  totdam  =  total damage. In this program is crack length
C  dtotdam =  same in double precision. Use this to count. 
C  ef = monotonic fracture strain
C  maxpd = maximum no of points possible in PD list
C  maxpoints = max no. of pts in Load history
C  maxnio = max no. reversals at which output is requested



C     These are used to store the equal spaced Snom. fitted data file.
      real StressAmp(1500), StrainAmp(1500), SnominalAmp(1500)
      integer*4 nmatdata,maxmatdata
C      real FractureStress,FractureStrain,Emod
      logical debugMat
      common/MATERIAL/ StressAmp,StrainAmp,SnominalAmp,
     &      snominalInterval,nmatdata,maxmatdata,debugMat
C     & FractureStress,FractureStrain,Emod

      real*4  deltaK(50),dadn(50),logdeltaK(50),logdadn(50),
     &        logdiffdK(50),logdiffdadn(50)
      logical debugDadn
      common/DADN/ deltaK,dadn,logdeltaK,logdadn,logdiffdK,logdiffdadn,
     &             ndadn,maxdadn,debugDadn


C     Matrices for storing Mm and Mb
      real*4 mb00(51,11),mm00(51,11),mb90(51,11),mm90(51,11)
      integer*4 nmmdatarow,maxmmdatarow, nmmdatacol, maxmmdatacol
C     Limits and intervals of input data used for quicker interpolation
      real*4 startaoc, endaoc, deltaaoc
      real*4 startaob, endaob, deltaaob
      logical debugMm,lactivateMmMb
      common/MMDATA/   mb00,mm00,mb90,mm90,
     &       nmmdatarow,maxmmdatarow, nmmdatacol, maxmmdatacol,
     &      startaoc,endaoc,deltaaoc, startaob,endaob,deltaaob,debugMm,
     &      lactivateMmMb

C     Matrices for storing Mkm and Mkb
      real*4 mkb00(18,200),mkm00(18,200),mkb90(18,200),mkm90(18,200)
      integer*4 nmkdatarow,maxmkdatarow, nmkdatacol, maxmkdatacol
C     Limits and intervals of input data used for quicker interpolation
      real*4 startaoc2, endaoc2, deltaaoc2
      real*4 startaob2, endaob2, deltaaob2
      logical debugMk,lactivateMkmMkb
      common/MKDATA/  mkb00,mkm00,mkb90,mkm90,
     &      nmkdatarow,maxmkdatarow, nmkdatacol, maxmkdatacol,
     &      startaoc2,endaoc2,deltaaoc2, startaob2,endaob2,deltaaob2,
     &      debugMk,lactivateMkmMkb
      real*4 Lweld

C     Matrix for storing fw
      real*4 fw(26,26)
      integer*4 nfwdatarow,maxfwdatarow, nfwdatacol, maxfwdatacol
C     Limits and intervals of input data used for quicker interpolation
      real*4 startcow, endcow, deltacow
      real*4 startaob3, endaob3, deltaaob3
      logical debugfw,lactivatefw
      common/FWDATA/ fw
     &      nfwdatarow,maxfwdatarow, nfwdatacol, maxfwdatacol,
     &   startcow,endcow,deltacow, startaob3,endaob3,deltaaob3,debugfw,
     &   lactivatefw
C     The S/R getfw.f does both the create data matrix, and the interpolation
C         The n...row etc parameters are set in the S/R.


      logical logiExist  !used in opening  fadInput.rand   file

C     These are the push-down list members:
      real*4 tlimL00(4000),climL00(4000),
     &       tlimL90(4000),climL90(4000)
Css     &  ,tlstr00(4000), clstr00(4000),tlsts00(4000),clsts00(4000)
Css     &  ,tlstr90(4000), clstr90(4000),tlsts90(4000),clsts90(4000)
     &     ,tldam00(4000),cldam00(4000)
     &     ,tldam90(4000),cldam90(4000)
      integer itlnrev00(4000),iclnrev00(4000),
     &        itlnrev90(4000),iclnrev90(4000)
C     The damage (crack length) counters need to be real*8 because we
C     may be trying to add a very small crack increment to a large crack length.
      real*8 tltotCrk00(4000),cltotCrk00(4000)
     &      ,tltotCrk90(4000),cltotCrk90(4000)
      real*8 dtotdam00,dtotdam90, daminc00,daminc90, damold00,damold90
C      The reason for pushing the tltotCrk and tlnrev numbers are for future
C      disappearing memory due to crack extension.
C
C      We could also reduce the no. of list entries by "binning"  the Kmax,Kmin
C      values into, say 2000 finite values or bins. Note that its not a good
C      idea to bin (or discretize) other things such as stress-strain curves etc.
C      That would be like Wetzel's line segment memory, which causes all sorts of
C      problems near the bin "edges", mainly because of the Neuber solutions
C      interacting with the stress-strain solutions.

      character*300  inp300,jnp300,Cwebpage ! used to read in lines as chars.
      character*1    inpone(300),jnpone(300)
      character*10   inpten(30)
      equivalence (inpone(1), inpten(1), inp300)
      equivalence (jnpone(1),jnp300)

      character*10 name1, name2, stressunits
      character*10 strainunits, lifeunits, sorttype
      character*30 names30(10), firstfield, ctail
      character*30 cfiletype, Cdatatype
      character*80 argv, matfile, fwfile, kprimefile, dadnfile
      character*80 matname
      character*80 probType,histfile,dadnType,dadnTableFile

      integer*4 iargc,nargc

c     Load history storage.  If changing dimensions, also change same 
C                             in S/R getPeakLoads()
C      integer*4  sae(10000)
C     Stress membrane, bending, and total storage:
      real*4 stsm(5000),stsb(5000),ststot(5000)
      integer*4 iloadflag(5000) ! = 1 if ok, =0 not used, or intValue if repeat
      real*4 ststotmax,ststotmin,ststotwindow
      integer*4 nloads
      logical debugLoads
      common /LOADS/ stsm,stsb,ststot,iloadflag, ststotmax,ststotmin,
     &               ststotwindow,nloads,debugLoads


      real*4 ldo00,ldo90,lobj00,lobj90

C     Set up the discretized  deltaK table: basically the range of deltaK
C     is divided into  ndiscMax points, equally spaced by discDKinterval.
C     After each deltaK  values is computed, it is then discretized to
C     reduce the number of P.D. list entries, which normally gets very
C     large as the Mkm, Mkb factors become smaller as the cracks propagate
C     away from the weld or notch area.  Since we have discrete values of
C     deltaK we may as well discretize dadn also and, later, the 
C     corresponding values of local stress and strain.
      real*4 discDK(2000),discDadn(2000)   ! we don't really need discDK()
      real*4 discDKinterval
      integer ndiscMax        ! max storage for disc. values

c     Reversals at which PDList output occurs
      integer*4 nio(23)/2,3,4,5,8,70,100,200,500,1000,2000,5000,
     &    10000,20000,50000,100000,200000,300000,500000,1000000,
     &    5000000,10000000,100000000/
c     After last number in nio() put out data every nio(maxnio)
c     Note that as the crack propagates away from the Notch stress 
c     raiser that the PDLists may be VERY large: = maxpd
c     Thus we will need to place a limit on the no. PDlist printed out.

      logical prin
      logical stabl
      common /STAB/ stabl

      pi=3.1415927

      debugMat=.false.     !use to debug the Neuber and stress-strain portion
      debugDadn=.false.    ! use for the dadn  section
      debugfw=.false.      ! use for the Finite width correct.
      debugMm=.false.      ! use for Mm00,Mb00,Mm90,Mb90 read and interpolate sections
      debugMk=.false.      ! use for Mkm,Mkb,Mkm,Mkb, 00 and 90 read and interp. sections
      debugLoads=.false.   ! use to debug load read and peakpick section.

C     Storage area limits. Change this if you change above real* and int*
      maxmatdata=1500 ! Stress,strain,life store max
      maxdadn=50     ! da/dn data store max
      ndiscMax=2000   ! store for discretized dadn()

      maxmmdatarow=51  ! Max no of rows in mb and mm matrices
      maxmmdatacol=11  ! max no. of columns
      maxmkdatarow=18  ! Max no. of rows in Mkb and Mkm matrices
      maxmkdatacol=200 ! Max no. of columns "

      maxloads=5000   ! max load storage
      maxpd=4000     ! Push down list storage max
      m=maxpd
      maxnio=23       ! Max store for Rev data output
      nioLast=nio(maxnio)

C     Test if -Wuninitilized  warning works in gfortran:
C      i=ifix(x)
C     Works!
    
C      Initilize some variables.
C      Origin and zero
      eorg=0.0
      sorg=0.0
      nact=0

      nptc00=0
      nptt00=0
      nptc90=0
      nptt90=0
      do 20 i=1,maxpd
        tlimL90(i)=0.    !peak in tensile nominal load or deltaK
        climL90(i)=0.    !peak in compr.  nominal load or deltaK
Css        tlstr90(i)=0. !peak in tens. strain
Css        clstr90(i)=0. !  "     comp.   "
Css        tlsts90(i)=0. !peak in tens. stress
Css        clsts90(i)=0. !  "     comp.   "
        tldam90(i)=0.    !damage or delta a for that ramp
        cldam90(i)=0.
        tltotCrk90(i)=0. ! total damage at that point
        cltotCrk90(i)=0.
        itlnrev90(i)=0.   ! rev. at which the above occured.
        iclnrev90(i)=0.

        tlimL00(i)=0.
        climL00(i)=0.
Css        tlstr00(i)=0.
Css        clstr00(i)=0.
Css        tlsts00(i)=0.
Css        clsts00(i)=0.
        tldam00(i)=0.
        cldam00(i)=0.
        tltotCrk00(i)=0.
        cltotCrk00(i)=0.
        itlnrev00(i)=0
        iclnrev00(i)=0
   20 continue



C---------------------------  Run time input data------------------
  184 continue
      write(6,185)
      write(0,185)
  185 format("# plateWeldflaw.f vers. 3.10"/
     & "#Usage: plateWeldflaw  scale <histfile  >outfile"/)

      nargc = iargc()
C     Note that in HP fortran the arg numbers must be changed by -1
C     and that iargc probably includes the "plateWeldflaw" as an arg.
      if( nargc .ne. 1)then
        write(0,*)" plateWeldflaw:  usage ERROR"
        write(6,*)" plateWeldflaw:  usage ERROR"
        write(0,186)
        write(6,186)
  186  format(
     &   "#Usage:      plateWeldflaw Scale <histfile ",
     &   " >outputFile"//
     &   "# Where Scale is the multiplier applied to all history",
     &   " points.(both the Membrane and Bending load/stresses) "/
     &   "# NOTE!: The above factor will be applied to the load"/
     &   "# history effectively AFTER the factors "/
     &   "# in the ""pdprop.env"" file are applied "
     &   "# Stopping now."
     &   )
        stop
      endif

C       The first arg is the history multiplication factor
        jvect=1
        call getarg(jvect,argv)
        read(argv,*,err= 178)scaleValue
        write(6,*)"#scaleValue= ",scaleValue
        if(scaleValue .eq. 0.0)go to 178

C        jvect=jvect+1
C        call getarg(jvect,argv)
C        read(argv,*,err=179)xmeanAdd
C        write(6,*)"#xmeanAdd= ",xmeanAdd
C       Both scaleValue and xmeanAdd have been read in successfully
        go to 190

C     Bad arguments in command line
  178 write(0,*)"# ERROR: bad scaleValue argument=",argv
      stop
C  179 write(0,*)"# ERROR: bad meanAdd argument= ",argv
C      stop

  190 continue
      write(6,191)
      write(0,191)
  191 format("#Opening pdprop.env file...")
C     Initilize the things to be read to checkable items
C     to make sure they have been entered.
      probType= " "
      iactivateMmMb= -1
      iactivateMkmMkb= -1
      iactivatefw= -1
C     The calling script will read the material file name and place the
C         results into the file "matfile"
      matfile= "matfile"

C     The history file will be read from standard input (device 5)
      histfile= "stdin"
      xmagfactorm= 0.    ! Set no data read flag
      xmagfactorb= 0.
      xmeanAddm=-1.0e20  ! Hopefully no one will ever use this :(
      xmeanAddb=-1.0e20  !   (unlikely since its basically MPa)
      
C     The calling script will read dadnType and create or copy to "dadnTable" file
      dadnType= " "
      dadnTablefile= "dadnTable"

      Bthick= -1.
      Width=  -1.
      rinternal= -1.

      azero= -1.
      czero= -1.
      Lweld= -1.
      maxHistReps= -1
      blockSkip= -9999.
      isavelevel= 0    !this is the default level if none is specified


C     Remove the following later if not needed
C     Older rcrock version items:
C      maxrevs=0
C      crackStart= -1.0
C      matfile= " "
C      fwfile= " "
C      xfwmult= 0.0
C      kprimefile= " "
C      xkpmult= 0.0
C      history will be read from standard input in this version.
C      histfile= " "
C      histScale= 0.
C      histMeanAdd= -9999.

C -----------   Open and read in the pdprop.env  file
C     In this file all lines should begin with a #  or are blank lines
      open(unit=10,file="pdprop.env")
      ninput=0
  800 continue
c     Loop back to here for next input line.

      read(10,"(a300)",end=380)inp300
      ninput=ninput+1
Cdebug      write(0,*)" read input line ",ninput

C     Check for blank line
      if(inp300.eq." ")then
C        write(6,"(a1)")" "
        go to 800
      endif

      if(inpone(1).ne."#")then
C        We may have a data line, or someone screwed up and put the # later in line.
C        See if 1st char is a # later in line
         do 805 i=1,300
           if(inpone(i).eq." ") go to 805
C           No? 1st non-blank found, if # its not a data line
            loc=i
           if(inpone(i).eq."#") then
C            Shift the whole mess over to begining of field
             inew=0
             do 803 j=loc,300
              inew=inew+1
              inpone(inew)=inpone(j)
  803        continue
Cdebug        write(0,*)"Shifted a comment: ",(inpone(j),j=1,inew)
C            Ok, now its a nice comment. Go play with it.
             go to 820
          else
C         The first non blank is not a #
          write(0,*)"# Skipped garbage in *.env file: line no.= ",ninput
          write(0,*)"# Text is= ",inp300
          write(6,*)"# Skipped garbage in *.env file: line no.= ",ninput
          write(6,*)"# Text is= ",inp300
          go to 800
          endif
  805    continue


      endif
  820 continue
C     First char was a #
C     pdprop.env file input line has a # in 1st col.  
C     See if it has a keyword.

      if(inpone(1).ne."#")then
C       something is bad in program
        write(0,*)" ERROR 820, sorry prog. messed up call ? admin"
        stop
      endif

C     Ok, its a nice comment.  Figure out if its a special tag.
      read(inp300,*)firstfield


      if(firstfield .eq."#TYPE=" .or.
     &   firstfield .eq."#Type=" .or.
     &   firstfield .eq."#type=" )then
         read(inp300,*) firstfield, probType
         write(6,833)probType
  833    format("#TYPE= ",a80)
         go to 800
      endif

      if(firstfield .eq."#ACTIVATE_MmMb=" .or.
     &   firstfield .eq."#Activate_MmMb=" .or.
     &   firstfield .eq."#activate_MmMb=" )then
         read(inp300,*) firstfield, iactivateMmMb
         write(6,835)iactivateMmMb
  835    format("#iactivateMmMb= ",i3)
         lactivateMmMb=.true.
         if(iactivateMmMb.eq.0)lactivateMmMb=.false. ! turn off
         go to 800
      endif

      if(firstfield .eq."#ACTIVATE_MkmMkb=" .or.
     &   firstfield .eq."#Activate_MkmMkb=" .or.
     &   firstfield .eq."#activate_MkmMkb=" )then
         read(inp300,*) firstfield, iactivateMkmMkb
         write(6,837)iactivateMkmMkb
  837    format("#iactivateMkmMkb= ",i3)
         lactivateMkmMkb=.true.
         if(iactivateMkmMkb.eq.0)lactivateMkmMkb=.false. ! turn off
         go to 800
      endif

      if(firstfield .eq."#ACTIVATE_fw=" .or.
     &   firstfield .eq."#ACTIVATE_FW=" .or.
     &   firstfield .eq."#ACTIVATE_Fw=" .or.
     &   firstfield .eq."#Activate_fw=" .or.
     &   firstfield .eq."#activate_fw=" )then
         read(inp300,*) firstfield, iactivatefw
         write(6,838)iactivatefw
  838    format("#iactivatefw= ",i3)
         lactivatefw=.true.
         if(iactivatefw.eq.0)lactivatefw=.false. ! turn off
         go to 800
      endif


      if(firstfield .eq."#B=" .or.
     &   firstfield .eq."#b=" )then
         read(inp300,*) firstfield, Bthick
         write(6,844)Bthick
  844    format("#B= ",E14.7," # Thickness, mm.")
         go to 800
      endif

      if(firstfield .eq."#W=" .or.
     &   firstfield .eq."#w=" )then
         read(inp300,*) firstfield, Width
         write(6,845)Width
  845    format("#W= ",E14.7," # width, mm.")
         go to 800
      endif

      if(firstfield .eq."#ri=" .or.
     &   firstfield .eq."#Ri" .or.
     &   firstfield .eq."#RI" )then
         read(inp300,*) firstfield, rinternal
         write(6,846)rinternal
  846    format("#ri= ",E14.7," # interal pipe diam, mm.")
         go to 800
      endif

      if(firstfield .eq."#azero=" .or.
     &   firstfield .eq."#AZERO=" )then
         read(inp300,*) firstfield, azero
         write(6,847)azero
  847    format("#azero= ",E14.7," # initial crack depth, mm.")
         go to 800
      endif

      if(firstfield .eq."#czero=" .or.
     &   firstfield .eq."#Czero=" .or.
     &   firstfield .eq."#CZERO=" )then
         read(inp300,*) firstfield, czero
         write(6,848)czero
  848    format("#czero= ",E14.7," # 1/2 initial crack width, mm.")
         go to 800
      endif

      if(firstfield .eq."#L=" .or.
     &   firstfield .eq."#l=" )then
         read(inp300,*) firstfield, Lweld
         write(6,849)Lweld
  849    format("#L= ",E14.7," # weld feature width")
         go to 800
      endif

      if(firstfield .eq."#MATERIAL=" .or.
     &   firstfield .eq."#Material=" .or.
     &   firstfield .eq."#material=" )then
         read(inp300,*) firstfield, matname
         write(6,850)matname
  850    format("#MATERIAL= ",a80)
         go to 800
      endif
C
      if(firstfield .eq."#MAGFACTOR_m=" .or.
     &   firstfield .eq."#Magfactor_m=" .or.
     &   firstfield .eq."#magfactor_m=" )then
         read(inp300,*) firstfield, xmagfactorm
         write(6,852)xmagfactorm
  852    format("#MAGFACTOR_m= ",e14.7)
         go to 800
      endif

      if(firstfield .eq."#MAGFACTOR_b=" .or.
     &   firstfield .eq."#Magfactor_b=" .or.
     &   firstfield .eq."#magfactor_b=" )then
         read(inp300,*) firstfield, xmagfactorb
         write(6,854)xmagfactorb
  854    format("#MAGFACTOR_b= ",e14.7)
         go to 800
      endif

      if(firstfield .eq."#MEANADD_m=" .or.
     &   firstfield .eq."#Meanadd_m=" .or.
     &   firstfield .eq."#meanadd_m=" )then
         read(inp300,*) firstfield, xmeanAddm
         write(6,855)xmeanAddm
  855    format("#MEANADD_m= ",e14.7)
         go to 800
      endif

      if(firstfield .eq."#MEANADD_b=" .or.
     &   firstfield .eq."#Meanadd_b=" .or.
     &   firstfield .eq."#meanadd_b=" )then
         read(inp300,*) firstfield, xmeanAddb
         write(6,856)xmeanAddb
  856    format("#MEANADD_b= ",e14.7)
         go to 800
      endif
C
      if(firstfield .eq."#MAXREPS=" .or.
     &   firstfield .eq."#Maxreps=" .or.
     &   firstfield .eq."#maxreps=" )then
         read(inp300,*) firstfield, maxHistReps
         write(6,891)maxHistReps
  891    format("#MAXREPS= ",i20)
         go to 800
      endif


C     This is just a label check. The data itself will be lifted from the
C     standard file given in char variable: dadnTableFile
      if(firstfield .eq."#DADN=" .or.
     &   firstfield .eq."#Dadn=" .or.
     &   firstfield .eq."#dadn=" )then
         read(inp300,*) firstfield, dadnType
         write(6,892)dadnType
  892    format("#DADN= ",a80)
         go to 800
      endif

      if(firstfield .eq."#BLOCKSKIP=" .or.
     &   firstfield .eq."#Blockskip=" .or.
     &   firstfield .eq."#blockskip=" )then
         read(inp300,*) firstfield, blockskip
         write(6,893)blockskip
  893    format("#BLOCKSKIP= ",E14.7)
         go to 800
      endif

      if(firstfield .eq."#SAVELEVEL=" .or.
     &   firstfield .eq."#Savelevel=" .or.
     &   firstfield .eq."#savelevel=" )then
         read(inp300,*) firstfield, isavelevel
         write(6,894)isavelevel
  894    format("#SAVELEVEL= ",i2)
         go to 800
      endif



  350 continue
C     None of the above?  Then it must be a plain old
C     comment line.   Write it out too.
C       Count backwards and see where the last char is
        do 360 i=1,300
          j=300-(i-1)
          if(inpone(j).ne." ")then
C           found last char
            lastloc=j
            go to 362
          endif
  360   continue

  362   continue
      write(6,"(300a1)")(inpone(i),i=1,lastloc)
C     Go read another line
      go to 800

C     End of pdprop.env file reached
  380 continue
C     Check if critical items have been read in.
      close(unit=10)
      istop=0
      if(probType .eq. " ")then
        write(0,*)"#ERROR: #Type= not found."
        write(6,*)"#ERROR: #Type= not found."
        istop=1
      endif
      if(iactivteMmMb .eq. -1)then
        write(0,*)"ERROR: #ACTIVATE_MmMb= not found"
        write(6,*)"ERROR: #ACTIVATE_MmMb= not found"
        istop=1
      endif
      if(iactivteMkmMkb .eq. -1)then
        write(0,*)"ERROR: #ACTIVATE_MkmMkb= not found"
        write(6,*)"ERROR: #ACTIVATE_MkmMkb= not found"
        istop=1
      endif
      if(iactivtefw .eq. -1)then
        write(0,*)"ERROR: #ACTIVATE_fw= not found"
        write(6,*)"ERROR: #ACTIVATE_fw= not found"
        istop=1
      endif
      if(iactivateMmMb .eq. 0 .and. iactivateMkmMkb .eq. 0)then
        write(0,383)
        write(6,383)
  383   format("#WARNING!!!  WARNING!!!  Neither Mm, Mb, Mkm, Mkb",
     &         " are activated. Result: Mm=Mb=Mkm=Mkb=1 ")
C       this will not stop the program.
      endif
      if(iactivatefw .eq. 0)then
        write(0,384)
        write(6,384)
  384   format("#WARNING!!! WARNING!!! fw deactivated. Result fw=1.0")
      endif

      if(Bthick .eq. -1.0)then
        write(0,*)"ERROR:  #B=  not found"
        write(6,*)"ERROR:  #B=  not found"
        istop=1
      endif
      if(Width .eq. -1.0)then
        write(0,*)"ERROR:  #W=  not found"
        write(6,*)"ERROR:  #W=  not found"
        istop=1
      endif
      if(rinternal .eq. -1.0)then
        write(0,*)"ERROR:  #ri=  not found"
        write(6,*)"ERROR:  #ri=  not found"
        istop=1
      endif
      if(azero .eq. -1.0)then
        write(0,*)"ERROR:  #azero=  not found"
        write(6,*)"ERROR:  #azero=  not found"
        istop=1
      endif
      if(czero .eq. -1.0)then
        write(0,*)"ERROR:  #czero=  not found"
        write(6,*)"ERROR:  #czero=  not found"
        istop=1
      endif
      if(Lweld .eq. -1.0)then
        write(0,*)"ERROR:  #L=  not found"
        write(6,*)"ERROR:  #L=  not found"
        istop=1
      endif
C 
      if(xmagfactorm .eq. 0.0)then
        write(0,*)"ERROR:  #MAGFACTOR_m=  not found"
        write(6,*)"ERROR:  #MAGFACTOR_m=  not found"
        istop=1
      endif
      if(xmagfactorb .eq. 0.0)then
        write(0,*)"ERROR:  #MAGFACTOR_b=  not found"
        write(6,*)"ERROR:  #MAGFACTOR_b=  not found"
        istop=1
      endif
      if(xmeanAddm .eq. -1.0e20)then
        write(0,*)"ERROR:  #MEANDADD_m=  not found"
        write(6,*)"ERROR:  #MEANDADD_m=  not found"
        istop=1
      endif
      if(xmeanAddb .eq. -1.0e20)then
        write(0,*)"ERROR:  #MEANDADD_b=  not found"
        write(6,*)"ERROR:  #MEANDADD_b=  not found"
        istop=1
      endif

      if(maxHistReps .eq. -1)then
        write(0,*)"#ERROR: #MAXREPS=  not found"
        write(6,*)"#ERROR: #MAXREPS=  not found"
        istop=1
      endif
      if(blockSkip .eq. -9999. )then
        write(0,*)"#ERROR: #BLOCKSKIP=  not found"
        write(6,*)"#ERROR: #BLOCKSKIP=  not found"
        istop=1
      endif

      if(istop.eq. 1)then
         write(0,*)"# Stopping..."
         write(6,*)"# Stopping..."
         stop
      endif




C------------- Read in the Material Fitted Fatigue file Table-------------------

      snominalInterval= 0.   ! The delta between the points
      write(0,701)
      write(6,701)
  701 format("# #Opening matfile: Snominal, Stain, Stress Table ..."/
     &       "# #filename = matfile")
      open(unit=10,file=matfile)

      ninput=0
  700 continue
c     Loop back to here for next input line.

      read(10,"(a300)",end=750)inp300
      ninput=ninput+1
Cdebug      write(0,*)" read input line ",ninput

C     Check for blank line
      if(inp300.eq." ")then
C        write(6,"(a1)")" "
        go to 700
      endif

      if(inpone(1).ne."#")then
C        We may have a data line, or someone screwed up and put the # later in line.
C        See if 1st char is a # later in line
         do 705 i=1,300
           if(inpone(i).eq." ") go to 705
C           No? 1st non-blank found, if # its not a data line
            loc=i
           if(inpone(i).eq."#") then
C            Shift the whole mess over to begining of field
             inew=0
             do 703 j=loc,300
              inew=inew+1
              inpone(inew)=inpone(j)
  703        continue
Cdebug        write(0,*)"Shifted a comment: ",(inpone(j),j=1,inew)
C            Ok, now its a nice comment. Go play with it.
             go to 730
           else
C            The first non blank is not a #
             go to 710
           endif
  705      continue

  710      continue
C        1st non blank is not a #.  Check if its a number.
         if(inpone(loc).ne."+" .and.
     &      inpone(loc).ne."-" .and.
     &      inpone(loc).ne."." .and.
     &      inpone(loc).ne."0" .and.
     &      inpone(loc).ne."1" .and.
     &      inpone(loc).ne."2" .and.
     &      inpone(loc).ne."3" .and.
     &      inpone(loc).ne."4" .and.
     &      inpone(loc).ne."5" .and.
     &      inpone(loc).ne."6" .and.
     &      inpone(loc).ne."7" .and.
     &      inpone(loc).ne."8" .and.
     &      inpone(loc).ne."9"  )then
C           It must be a letter, not a number. Time to bomb out.
            write(0,715)ninput
            write(6,715)ninput
  715       format("# ERROR matfile: input line no. ",I5,
     &      " not a # and not a number. Fix program rdMatfile.f ")
            stop
         endif
C        Ok, its a number
         nmatdata=nmatdata+1
         if(nmatdata .gt. maxmatdata)then
           write(0,716)nmatdata
           write(6,716)nmatdata
  716      format("# Error too many data points:",i5,
     &            " recompile plateWeldflaw.f or reduce matfile data")
           stop
         endif
         read(inp300,*)SnominalAmp(nmatdata),StrainAmp(nmatdata), 
     &                 StressAmp(nmatdata)
         write(6,720)SnominalAmp(nmatdata),StrainAmp(nmatdata),
     &                 StressAmp(nmatdata),nmatdata
  720    format("#matfile ",f10.3,1x,f8.5,1x,f10.3,1x,i5)
         go to 700

      endif
  730    continue
C        Look for the interval comment line:
         read(inp300,*)firstfield
         if(firstfield.eq."#SnominalINTERVAL=")then
           read(inp300,*)firstfield,snominalInterval
           write(6,732)snominalInterval
  732      format("#matfile #Found SnominalINTERVAL= ",e14.7)
         endif
C          The interval is read in e14.7  but the Snominal data is f8.3  which
C          may cause a round-off problem if we ever go from strain or stress to Snom.
         go to 700

  750    continue   ! end of file comes here
C        All data is in. Close file
         close(unit=10)

C        Check if the nominal interval was found
         if(snominalInterval.eq.0.)then   !was not read in. Compute it instead.:
C          Assuming the first point was 0 0  0
C          then we should have about nmatdata= 1001 points in these memories.
C          Thus the interval is:
           snominalInterval= SnominalAmp(nmatdata)/(nmatdata-1)
C          This interval will be used in the interpolation process when finding
C          stress and strain given Snominal.
           write(6,752)snominalInterval
  752      format("#matfile #Computed #SnominalInterval= ",E14.7)
         endif


C--------------------  Read in the dadn data table -------------------
C       Table e.g.:
C        #NAME= A36merged  data from Newman, Haddad, Klingerman
C        #Data digitized from merged graph in file a36+1015dadn-2.png
C        #
C        #MPa*Sqrt(mm)  dadn mm/cycle
C        150.216  9.62054e-08
C        176.983  4.5623e-07
C        220.235  1.16017e-06
C        287.484  3.22409e-06
C        433.167  1.06976e-05
C        763.741  7.55681e-05
C        1240.59  0.000852041
C        1471.68  0.0033073
C        1675.69  0.0107468

C        Read in the table and convert to log-log  to store and use.
C        Computations will be done using log log co-ord interpolation.
      write(0,601)
      write(6,601)
  601 format("# Opening DeltaK   dadn   Table, file=dadnTable")
      open(unit=10,file=dadnTableFile)

      ninput=0
      ndadn=0
  600 continue     !Loop back to here for next input line.
      read(10,"(a300)",end=650)inp300
      ninput=ninput+1

      if(inp300.eq." ")then    ! Check for blank line
C        write(6,"(a1)")" "
        go to 600
      endif

      if(inpone(1).ne."#")then
C        We may have a data line, or someone screwed up and put the # later in line.
C        See if 1st char is a # later in line
         do 605 i=1,300
           if(inpone(i).eq." ") go to 605
C           No? 1st non-blank found, if # its not a data line
            loc=i
           if(inpone(i).eq."#") then
C            Shift the whole mess over to begining of field
             inew=0
             do 603 j=loc,300
              inew=inew+1
              inpone(inew)=inpone(j)
  603        continue
Cdebug        write(0,*)"Shifted a comment: ",(inpone(j),j=1,inew)
C            Ok, now its a nice comment. Go play with it.
             go to 630
           else
C            The first non blank is not a #
             go to 610
           endif
  605      continue
           go to 600  !assume garbage in line.

  610      continue
C        1st non blank is not a #  Check if its a number.
         if(inpone(loc).ne."+" .and.
     &      inpone(loc).ne."-" .and.
     &      inpone(loc).ne."." .and.
     &      inpone(loc).ne."0" .and.
     &      inpone(loc).ne."1" .and.
     &      inpone(loc).ne."2" .and.
     &      inpone(loc).ne."3" .and.
     &      inpone(loc).ne."4" .and.
     &      inpone(loc).ne."5" .and.
     &      inpone(loc).ne."6" .and.
     &      inpone(loc).ne."7" .and.
     &      inpone(loc).ne."8" .and.
     &      inpone(loc).ne."9"  )then
C           It must be a letter, not a number. Time to bomb out.
            write(0,615)ninput
            write(6,615)ninput
  615       format(" ERROR dadnfile: input line no. ",I5,
     &      " not a # and not a number. Fix data in file dadnTable ")
            stop
         endif
C        Ok, its a number
         ndadn=ndadn+1
         if(ndadn .gt. maxdadn)then
           write(0,616)ndadn
           write(6,616)ndadn
  616      format(" Error too many data points:",i5,
     &            " recompile plateWeldflaw.f or reduce dadnTable data")
           stop
         endif
         read(inp300,*)deltaK(ndadn),dadn(ndadn)
         logdeltaK(ndadn)= ALOG10(deltaK(ndadn))
         logdadn(ndadn)=ALOG10(dadn(ndadn))
         if(ndadn .gt.1)then  ! compute the diffs between points.
C          This will help speed up the interpolation calculation
           logdiffdk(ndadn)=logdeltaK(ndadn)-logdeltaK(ndadn-1)
           logdiffdadn(ndadn)=logdadn(ndadn)-logdadn(ndadn-1)
         endif
         write(6,620)deltaK(ndadn),dadn(ndadn),
     &              logdeltaK(ndadn),logdadn(ndadn),
     &              logdiffdk(ndadn),logdiffdadn(ndadn), ndadn
  620    format("#dadnTable ",6(e14.7,1x),i5)
         go to 600

      endif
  630    continue
C        All comment lines are just written out, or deleted
         go to 600

  650    continue   ! end of file comes here
C        All data is in. Close file
         logdiffdk(1)=0.  ! these will not be used, but set to 0. anyway
         logdiffdadn(1)=0.
         close(unit=10)
         write(6,652)ndadn
         write(0,652)ndadn
  652    format("#dadn data input completed. ndadn= ",i5)



C-------------- Read in the Mm,Mb, Mkm,Mkb files -----------------------------

      ivec=0  ! =0 read data files,  =1  interpolate
      if(lactivateMmMb)then
         call readMmMb00(ivec,iret)
         if(iret.ne.0)then
           write(0,*)"# Error ret. from readMmMb00() during"
           write(6,*)"# table Read. Stopping..."
           stop
         endif
         call readMmMb90(ivec,iret)
         if(iret.ne.0)then
           write(0,*)"# Error ret. from readMmMb90() during"
           write(6,*)"# table Read. Stopping..."
           stop
         endif
      endif

      if(lactivateMkmMkb)then
         call readMkmMkb00(ivec,iret)
         if(iret.ne.0)then
           write(0,*)"# Error ret. from readMkmMkb00() during"
           write(6,*)"# table Read. Stopping."
           stop
         endif
         call readMkmMkb90(ivec,iret)
         if(iret.ne.0)then
           write(0,*)"# Error ret. from readMkmMkb90() during"
           write(6,*)"# table Read. Stopping."
           stop
         endif
      endif

C     Create the  fw   table.
      ivec=0
      cow=0.2   !  set to something not real
      aob=0.2   !  set to something
      if(lactivatefw)then
        call fwSurfFlaw(ivec,irec,cow,aob,xfw)
        if(iret.ne.0)then
          write(0,*)"# Error:",iret," returned from fwSurfFlaw()"
          write(0,*)"#   during initilization of tables. Stopping..."
          stop
        endif
      endif


      izout=1

C     initilize the functions
      nrev=0
Cold      ds=det(0.,nrev)
Cold      de=fld(0.,nrev)
Cold      x=SMITH(0., 0.,0., 0.,0., 0.,0)
Cold      x=xkp(0., 0)
Cold      de=0.0
c
C------------------Get Load history file------------------------------
C     Expected format:
C     #Comment 1
C     #Comment line 2
C     #time     MembraneLoad    BendingLoad
C       0.0       xxx.xxx         yyy.yyy
C       z.z       xxx.xxx         yyy.yyy

C     The time column info is not really used.
C     Membrane and Bending loads will be altered by the #MAGFACTORm  etc lines
C     in the pdprop.env file and the calling args.

      write(0,901)
      write(6,901)
  901 format("# Getting Load history file from std.input ")
C      open(unit=10,file=histfile)

      ninput=0
      nloads=0
  900 continue     !Loop back to here for next input line.
      read(5,"(a300)",end=950)inp300
      ninput=ninput+1

      if(inp300.eq." ")then    ! Check for blank line
C        write(6,"(a1)")" "
        go to 900
      endif

      if(inpone(1).ne."#")then
C        We may have a data line, or someone screwed up and put the # later in line.
C        See if 1st char is a # later in line
         do 905 i=1,300
           if(inpone(i).eq." ") go to 905
C           No? 1st non-blank found, if # its not a data line
            loc=i
           if(inpone(i).eq."#") then
C            Shift the whole mess over to begining of field
             inew=0
             do 903 j=loc,300
              inew=inew+1
              inpone(inew)=inpone(j)
  903        continue
Cdebug        write(0,*)"Shifted a comment: ",(inpone(j),j=1,inew)
C            Ok, now its a nice comment. Go play with it.
             go to 930
           else
C            The first non blank is not a #
             go to 910
           endif
  905      continue
           go to 900  !assume garbage in line.

  910      continue
C        1st non blank is not a #  Check if its a number.
         if(inpone(loc).ne."+" .and.
     &      inpone(loc).ne."-" .and.
     &      inpone(loc).ne."." .and.
     &      inpone(loc).ne."0" .and.
     &      inpone(loc).ne."1" .and.
     &      inpone(loc).ne."2" .and.
     &      inpone(loc).ne."3" .and.
     &      inpone(loc).ne."4" .and.
     &      inpone(loc).ne."5" .and.
     &      inpone(loc).ne."6" .and.
     &      inpone(loc).ne."7" .and.
     &      inpone(loc).ne."8" .and.
     &      inpone(loc).ne."9"  )then
C           It must be a letter, not a number. Time to bomb out.
            write(0,915)ninput
            write(6,915)ninput
  915       format(" ERROR stdin: input line no. ",I5,
     &      " not a # and not a number. Fix data in load history file")
            stop
         endif
C        Ok, its a number --------------read in load set
         nloads=nloads+1
         if(nloads .gt. maxloads)then
           write(0,916)nloads
           write(6,916)nloads
  916      format(" Error too many data points:",i5,
     &         " recompile plateWeldflaw.f or reduce load history data")
           stop
         endif
         read(inp300,*,err=925)xtime,xmembrane,xbending
         iloadflag(nloads)=1  ! used to filter loads 1=ok, 0=delete in the
C        s/r getPeakLoads(). Also in future code will be a repeat factor
C        that is read as input.

C        Adjust to mag. and mean shift in *.env file
         xmembrane=xmembrane*xmagfactorm + xmeanAddm
         xbending= xbending*xmagfactorb  + xmeanAddb
C        Now scale by arg1  in the command that calls this program
         stsm(nloads)= xmembrane*scaleValue
         stsb(nloads)= xbending*scaleValue
C        Find the total stress for Rainflow counting
         ststot1= stsm(nloads) + stsb(nloads)
         if(nloads .eq. 1)then
            ststotmax=ststot1
            ststotmin=ststot1
         endif
         if(ststot1 .gt. ststotmax) ststotmax=ststot1
         if(ststot1 .lt. ststotmin) ststotmin=ststot1
         ststot(nloads)=ststot1
         write(6,920)stsm(nloads),stsb(nloads),ststot(nloads),
     &         iloadflag(nloads),nloads
  920    format("#history.org ",3(f7.1,1x),i8,1x,i6)
         go to 900

  925    write(0,926)nloads,inp300
         write(6,926)nloads,inp300
  926    format("#READ ERROR: history file: data line no.= ",i9/
     &   "#LINE= ",a300/ "# Stopping now.")
         stop

      endif
  930    continue
C        Yes, first char was a #
C        All comment lines are just written out, or deleted
         go to 900

  950    continue    ! end of file comes here
         if(nloads.eq.0)then
            write(6,951)
            write(0,951)
  951       format("#Error: histfile: contains no data !")
            stop
         endif
C        All data is in. Close file
C         close(unit=10)
         write(6,952)nloads,ststotmax,ststotmin
         write(0,952)nloads,ststotmax,ststotmin
  952    format("#history #Data input completed. nloads= ",i5/
     &   "#history #StotMax= ",f7.1/"#history #StotMin= ",f7.1/
     &   "#history #Where Stot = Smembrane + Sbending"//)
         

C     stsm(5000),stsb(5000), ststotal(5000) are the history stores
C-----------------We must now eliminate non-reversal points------------------
C     created by the addition of Smembrane and Sbending
C     i.e.: If Sm and Sb are not proportional (viewed over time) then when they
C     are superimposed to get the "total" stresss near the crack, some non-reversal
C     points may be in the history. These must be eliminated before applying the
C     push-down list material memory rules.  Also there may be created some small
C     1/2 cycles that are not worth running. (OK, its a value judgement) This
C     elimination window is computed as a %tage of max and min stress:

      ststotwindow= 0.02*(ststotmax-ststotmin)
      write(0,954)ststotwindow
      write(6,954)ststotwindow
  954 format("# Eliminating non-reversal points from history..."/
     &"#history #Elimination window = 2% of",
     &" (StressMax-StressMin)=",f7.2/ 
     &"#history #Any 1/2 cylce smaller than this will be eliminated...")

      ivec=1
      iret=0
      call getPeakLoads(ivec,iret)
      if(iret.ne.0)then
        write(0,*)"#ERROR: getPeakLoads() iret=",iret," Stopping."
        stop
      endif
      

C------------------ Create the discretized calculation tables------------------
      xdeltaK=0.
      discDK(1)=0.
      discDadn(1)=0.
      discDKinterval=deltaK(ndadn)/(ndiscMax-1) ! deltaKmax =deltaK(ndadn)
      i=1
      write(6,440)xdeltaK,discDadn(i),i

      do 450 i=2,ndiscMax
        xdeltaK=xdeltaK+discDKinterval
        discDK(i)=xdeltaK
        call getCracks(iret,xdeltaK,ydadn)
C           an error here in getCracks will stop program in getCracks
        discDadn(i)=ydadn
        write(6,440)xdeltaK,ydadn,i
  440   format("#discrete ",e14.7,1x,e14.7,i6)
  450 continue
      write(0,455)ndiscMax
      write(6,455)ndiscMax
  455 format("#discrete #Discretized deltaK vs dadn done. no. pts=",i6)


C----------------------binary output file-------------------------------------
C     Open the binary (direct access) record file for data output
C     Get a filename for the standard input stream (doesnt work)
C      inquire(unit=5, NAME=stdinFileName)
      write(0,460)
      write(6,460)
  460 format("# Opening random access output file:  fadInput.rand ...")
      inquire(file="fadInput.rand", EXIST= logiExist)
      if(logiExist)then
        write(0,*)"#Error: an old copy of file  fadInput.rand  exists."
        write(0,*)"#   You need to rename it or remove it before we"
        write(0,*)"#   can run the simulation.  Stopping now..."
        write(6,*)"#Error: an old copy of file  fadInput.rand  exists."
        write(6,*)"#   You need to rename it or remove it before we"
        write(6,*)"#   can run the simulation.  Stopping now..."
        stop
      endif

C     Ok,  previous copies do not exist. open it.
      open(unit=60, file="fadInput.rand", access="direct", 
     &     form= "unformatted", status= "new", recl= 72)
      write(0,462)
      write(6,462)
  462 format("#Random Access output file: fadInput.rand   opened.")
      nrecord=1  !this will be incremented by 1 upon 1st use.



C---------------------- Start Cycling--------------------------------------------
C     Load or nominal stress is used to model material memory. At this time
C     the nom. stresses are same for both 00 and 90 deg cracks,  but the crack
C     geometry creates diff. deltaK for each.   deltaK is used to run the memory.
C     Basically there are two push-down list memory models running in parallel.
C     Each crack point has its own "local" stress-strain behavior
C     Program flow and logic are pretty much the same as concepts of
C     original program  rcrock.f from thesis.

      nblk=1
      nrev=0

      lobj00=0.
      ldo00=0.
      eobj00=0.
      sobj00=0.

      lobj90=0.
      ldo90=0.
      eobj90=0.
      sobj90=0.

      iupdown00=+1
      iupdown90=+1

      dtotdam00=czero  !crack length "c" for 00deg surface crack point
      damold00=0.
      daminc00=0.

      dtotdam90=azero  !crack length "a" for 90deg depth crack point
      damold90=0.
      daminc90=0.

      if(.not.lactivateMmMb)then ! See if Mm and Mb are shutdown
        xMm00=1.0
        xMb00=1.0
        xMm90=1.0
        xMb90=1.0
      endif

      if(.not.lactivateMkmMkb)then ! See if Mkm and Mkb are shutdown
        xMkm00=1.0
        xMkb00=1.0
        xMkm90=1.0
        xMkb90=1.0
      endif

      if(.not.lactivatefw)xfw=1.0  ! See if FiniteWidth Corr. is shutdown

C      write(6,120) nrev,dtotdam90,dtotdam00,nblk,daminc90,daminc00
      write(6,119)   ! write out the header for crack data
  119 format("#crackdat= #   NREV         a 90          c 00      ",
     &       "    NBLK         a inc           c inc")

 3000 continue  ! =================Top of Cycling loop====================
      ldo90=lobj90
      ldo00=lobj00
Css      eo90=eobj90
Css      so90=sobj90
      
      nrev=nrev+1
      nact=nact+1
      if(nptt90.eq.maxpd .or. nptc90.eq.maxpd .or.
     &   nptt00.eq.maxpd .or. nptc00.eq.maxpd)then
         write(0,118)maxpd,nptt90,nptc90,nptt00,nptc00
         write(6,118)maxpd,nptt90,nptc90,nptt00,nptc00
 118     format("#Error: one or more of the PushDown list counters >",
     &   "maxpd= ",i6," nptt90=",i6," nptc90=",i6,
     &   " nptt00=",i6," nptc00=",i6)
         stop
      endif

cccccccccccccccccccccccccccccccccccccccccccccc  Block Repeat
C     The user must make certain that end of block is  compatible with 
C     the begin of block.  The program will start at 0 stress(load) but
C     the history does not need to include this start point. The last
C     point in the history and the first and 2nd points MUST form reversals.
C    E.g:     2nd_last_pt    last_pt   1st_pt   2nd_pt
C                 +100        -90       90       -90       is allowed
C                 +100        +50       0         +50      is NOT allowed
      if(nrev .eq. 1 .and. stsm(1) .eq.0. .and. 
     &   stsb(1) .eq. 0.0) nact=2  !zero range, skip this half cycle
      if(nact .le. nloads) go to 3001
C       end of block, increment the blk count and reset nact=1
        nblk=nblk+1
C       daminc and damold s  are used to skip a block if damage is same
        daminc00=dtotdam00 - damold00
        damold00=dtotdam00
        daminc90=dtotdam90 - damold90
        damold90=dtotdam90
        nact=1
 3001 continue

Cold      lnomStress= ststot(nact)
Cold      lobj= lobj*xkp(totdam,nrev)
      ivec=1   !get interpolate data if req.
      totdam00=sngl(dtotdam00)
      totdam90=sngl(dtotdam90)
      aoc=totdam90/totdam00
      if(aoc .gt. 2.0)aoc=2.0

      aob=totdam90/Bthick
      if(aob .gt. 1.0)then
         write(0,3002)totdam90,Bthick
         write(6,3002)totdam90,Bthick
 3002    format("#END: a/B > 1.0 : a= ",e14.7," B= ",e14.7)
         goto 9000   !stop
      endif

Cdebug      write(6,*)"#debug: lactivateMmMb,lactivateMkmMkb,lactivatefw: ",
Cdebug     &  lactivateMmMb,lactivateMkmMkb,lactivatefw
      if(lactivateMmMb)then ! if not, all are equal to 1.0 (set above)
        if(aoc .gt. 2.0)then
           write(0,3003)totdam90,totdam00
           write(6,3003)totdam90,totdam00
 3003      format("#END: a/c > 2.0 : a= ",e14.7," c= ",e14.7)
           goto 9000   !stop
        endif
        call getMmMb00a90(ivec,iret,aoc,aob,xMm00,xMb00,xMm90,xMb90)
        if(iret .gt. 0)then
C          Error return  detected. to to stop
           goto 9000
        endif
      endif

      if(lactivateMkmMkb)then ! if not, all are equal to 1.0 (set above)
        if(aoc .gt. 0.95)then
           write(0,3004)totdam90,totdam00
           write(6,3004)totdam90,totdam00
 3004      format("#END: a/c > 0.95 : a= ",e14.7," c= ",e14.7)
           goto 9000   !stop
        endif
        call getMkmMkb00a90(ivec,iret,aoc,aob,
     &              xMkm00,xMkb00,xMkm90,xMkb90)
Cdebug        write(6,*)"#debug xMkm00,xMkb00,xMkm90,xMkb90=",
Cdebug     &                    xMkm00,xMkb00,xMkm90,xMkb90
        if(iret .gt. 0)then
C          Error return  detected. go to stop
           goto 9000
        endif
        if(xMkm00 .lt. 1.0)xMkm00=1.0
        if(xMkb00 .lt. 1.0)xMkb00=1.0
        if(xMkm90 .lt. 1.0)xMkm90=1.0
        if(xMkb90 .lt. 1.0)xMkb90=1.0
      endif

      cow= totdam00/Width
      if(lactivatefw)then ! if not fw was set to 1.0 above
        if(cow .ge. 0.4)then
          write(0,3006)totdam00,Width
          write(6,3006)totdam00,Width
 3006     format("#END: fw: 2c/W .GT. 0.8, c=",e14.7,1x,"W= ",e14.7)
          goto 9000   !stop
        endif
        call fwSurfFlaw(ivec,iret,cow,aob,xfw)
Cdebug        write(0,*)"fwdebug: cow,aob,xfw: ",cow,aob,xfw
        if(iret .ne. 0)then
C         Error return from finite width code. Stop.
          goto 9000 ! stop
        endif
      endif

C     Apply factors to stresses  as per BSstandard:
C     Note that BS7910 is not terribly clear on this.
C     Assume: Bulge M=1,   km=1  ktm=1  ktb=1
      stsMembrane=stsm(nact)
      stsBending=stsb(nact)

      rootPiA=sqrt(pi*totdam90)
      lobj90=xfw*(xMkm90*xMm90*stsMembrane + xMkb90*xMb90*stsBending )
      lobj90=lobj90*rootPiA

C     The interpretation of BS7910:2005  Annex S.2 pg 261
      rootPiC=sqrt(pi*totdam00)
      lobj00=xfw*(xMkm00*xMm00*stsMembrane + xMkb00*xMb00*stsBending )
      lobj00=lobj00*rootPiC

C     discretize  lobj90 and lobj00
      lobj90= float(ifix(lobj90/discDKinterval)) *discDKinterval
      lobj00= float(ifix(lobj00/discDKinterval)) *discDKinterval
    
Cdebug      write(6,*)"#db: lobj90,lobj00,xfw,Mkm90,Mm90 = ",
Cdebug     &           lobj90,lobj00,xfw,xMkm90,xMm90
      if(lobj90.eq.ldo90 .and. lobj00.eq.ldo00)then
C       Skip, its a nothing reversal.  It should probably be a delta
C       check.  (but what if one is zero, but the other is not?)
        write(0,3007)nrev,nblk,nact
        write(6,3007)nrev,nblk,nact
 3007     format("#Warning: Same target as previous lobj90=ldo90 and"
     &    ,"lobj00=ldo00 at nrev=",i9," nblk=",i9," nact=",i9/
     &     "# Skipping this stress...")
        go to 3000
      endif

C     Crack length variables may have to be real*8  because adding
C     a very small da increment may not show up if crack is big.
      totdam90=sngl(dtotdam90)
      totdam00=sngl(dtotdam00)
      if(isavelevel .gt. 0)then
        write(6,120) nrev,totdam90,totdam00,nblk,nact,lobj90,lobj00,
     &             xMm90,xMb90,xMm00,xMb00,
C     &             xMkm90,xMkb90,xMkm00,xMkb00,xfw,nptt90,nptt00
     &             xMkm90,xMkb90,xMkm00,xMkb00,xfw,
     &             stsMembrane,stsBending
  120   format("#crk=",i9,2(1x,e14.7),i8,1x,i6,2(1x,f7.2),
C     &             9(1x,f7.4),i4,1x,i4, 1x,f6.0,1x,f6.0 )
     &             9(1x,f7.4), 1x,f6.0,1x,f6.0 )
      endif
C     We always write to the binary out file. The first record written
C     is  nrecord=2.   Rec no. 1 is written at end of test.
        nrecord=nrecord+1
        write(60,rec=nrecord)nrev,totdam90,totdam00,nblk,nact,
     &             lobj90,lobj00,xMm90,xMb90,xMm00,xMb00,
     &             xMkm90,xMkb90,xMkm00,xMkb00,xfw,
     &             stsMembrane,stsBending

      prin=.false.
      if(nrev .eq. nio(izout)) prin =.true.
      if(nrev .gt. maxHistReps) prin=.true.
      if(.not. prin) go to 3050
      if(nptt90 .eq. 0  .or. nptc90 .eq. 0) go to 3050
      izout=izout+1
      if(izout.gt.maxnio)then
        izout=maxnio
        nio(izout)=nio(izout)*2
      endif
      if(nptt90 .gt. 10 .or. nptc90 .gt. 10) go to 3050

C     Often too much output.  Turn this off if isavelevel <3
      if(isavelevel .lt. 3) go to 3050

      write(6,121) nrev,totdam90,totdam00,nblk,nact
  121 format("#PD Before REV= ",i9,"  Cracks: a= ",E14.7
     &  ," c= ",E14.7,3X,"NBLK=",i6," NACT= ",I6
     & /"#PD: ",4x,"CLDAM90",3x,"CLIML90" )
      do 3039 ipr=1,nptc90
 3039 write(6,122) ipr,cldam90(ipr),climL90(ipr)
  122 format("#PD:",1x,i2,1x,E12.5,2x,F9.2)
   
      write(6,123)
  123 format("#PD:",5x,"TLDAM90",4x,"TLIML90")
      do 3045 ipr=1,nptt90
      write(6,122) ipr,tldam90(ipr),tlimL90(ipr)
 3045 continue

C---------------print the 00  PD lists
      write(6,124) nrev,totdam90,totdam00,nblk,nact
  124 format("#PD: Before REV= ",i9,"  Cracks: a= ",E14.7
     &  ," c= ",E14.7,3X,"NBLK=",i6," NACT= ",I6
     & /"#PD:",4x,"CLDAM00",3x,"CLIML00" )
      do 3046 ipr=1,nptc00
 3046 write(6,122) ipr,cldam00(ipr), climL00(ipr)
   
      write(6,125)
  125 format("#PD:",5x,"TLDAM00",3x,"TLIML00")
      do 3047 ipr=1,nptt00
 3047 write(6,122) ipr,tldam00(ipr), tlimL00(ipr)

 3050 continue
C ----------------------------------------------------------------
C
C     Check for MAX. history repeats
      if(nblk .gt. maxHistReps)then
        write(0,130) nblk,totdam90,totdam00,nrev
        write(6,130) nblk,totdam90,totdam00,nrev
  130   format("# Max no. of History Reps. reached: nblk= ",i10/
     &      "#TOTDAM90= ",E14.7,"  TOTDAM00= ",e14.7," nrev= ",i9)
        goto 9000  !stop
      endif

      dld90=abs(lobj90-ldo90)
Cdebug      write(6,*)"#stsm(),stsb(),nact=",stsm(nact),stsb(nact),nact
Cdebug      write(6,*)"#dld90,lobj90,ldo90=",dld90,lobj90,ldo90,nrev
C      if(dld90.le. 0.05)then   !check for no actual half cycle
C     There is a slight possibility that one could have a 0 ramp in either
C     the  00 and/or the 90 deg direction, but we are not going to program 
C     for this now.

C     Going up or down ?   -----------------Crack Direction 90 deg------------
      if(lobj90 .lt. ldo90) go to 2100

C************ Going UP,  Tensile Direction **************************
C     Are we on the monotonic curve?
 1100 if(nptt90 .eq. 0) go to 1500
c     No. Has a exceedence  occurred?
 1110 if(lobj90 .gt. tlimL90(nptt90)) go to 1120

c     Is this Same as previous amplitude?
 1130 if(lobj90 .eq. tlimL90(nptt90) .and. nptt90 .ne. 1) go to 1135
      go to 1350

c     Is a loop being closed without the monotonic?
 1120 if(nptt90 .ne. 1) go to 1400

c     Is closure in connection  with the monotonic?
 1150 if(nptc90 .eq. 2) go to 1170

c     Check for impossible
 1160 if(nptc90 .eq. 1) go to 1165
      idump=1160
      go to 9999

C     Same load level as previous level.
 1135 continue
Css      dam90=SMITH( (lobj-ldo),tlsts(nptt90),clsts(nptc90),tlstr(nptt90),
Css     &            clstr(nptc90),totdam,nrev)
C     lobj90 and ldo90 exist. They are the deltaK values. Use them
      dld90=lobj90-ldo90
      if(dld90.le.0.)then
        write(6,*)"#Error: 1135:dld90,lobj90,ldo90 = ",
     &            dld90,lobj90,ldo90,nrev
      endif
Cvers1      call getCracks(iret,dld90,dam90)
      jpoint=dld90/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,1136)nrev,nblk,nact,dld90,deltaKmax
       write(6,1136)nrev,nblk,nact,dld90,deltaKmax
 1136  format("#Error: dld90.gt.deltaKmax =",i9,1x,i6,1x,i6,2(1x,e14.7))
       go to 9000  !stop
      endif
      dam90=discDadn(jpoint)/2.0
      nptc90=nptc90-1
      dtotdam90=dtotdam90+dble(dam90)
c     The closed loop is erased and the point of rev. is already there
Css      eobj90=tlstr90(nptt90)
Css      sobj90=tlsts90(nptt90)
      tldam90(nptt90)   =dam90
      tltotCrk90(nptt90)=dtotdam90
      itlnrev90(nptt90) =nrev
      go to 5000  ! Ramp is done go to 00 code

C     An unmatched 1/2 cycle is being forgotten and a return to the 
c     monotonic curve is occurring. Count the unmatched 1/2 cycle.
 1165 continue
Css      dam90=SMITH ( (tlimL90(1)-climL90(1)), tlsts90(1), clsts90(1),
Css     &         tlstr90(1),clstr90(1),totdam90,nrev)
      dld90=tlimL90(1)-climL90(1)
      if(dld90.eq.0.)then
        write(6,*)"#Error: 1165:dld90=0 tlimL90(1),climL90(1) = ",
     &            tlimL90(1),climL90(1),nrev
      endif
Cvers1            call getCracks(iret,dld90,dam90)
      jpoint=dld90/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,1136)nrev,nblk,nact,dld90,deltaKmax
       write(6,1136)nrev,nblk,nact,dld90,deltaKmax
       go to 9000  !stop
      endif
      dam90=discDadn(jpoint)/2.0
      dtotdam90=dtotdam90+dble(dam90)
      nptc90=0
      nptt90=0
      go to 1500

C     A loop is being closed and a return to the monotonic 
c     curve is occurring.  Damage is the same as the other half of
c     the cycle being closed.
 1170 continue
Css      dam90=SMITH( (tlimL90(1)-climL90(2)),
Css     &    tlsts90(1),clsts90(2),
Css     &    tlstr90(1),clstr90(2), totdam,nrev)
      dld90=tlimL90(1)-climL90(2)
      if(dld90.eq.0.)then
        write(6,*)"#Error: 1170:dld90=0 tlimL90(1),climL90(2)= ",
     &            tlimL90(1),climL90(2),nrev
      endif
Cvers1            call getCracks(iret,dld90,dam90)
      jpoint=dld90/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,1136)nrev,nblk,nact,dld90,deltaKmax
       write(6,1136)nrev,nblk,nact,dld90,deltaKmax
       go to 9000  !stop
      endif
      dam90=discDadn(jpoint)/2.0
      dtotdam90=dtotdam90+dble(dam90)
c     Eliminate the closed loop.
      nptc90=0
      nptt90=0
      go to 1500

C     A new entry in the P.D. list is being made.
 1350 continue
      dld90=abs(lobj90-climL90(nptc90))
Css      de90=FLD(dld,nrev)
Css      ds90=DET(de,nrev)
Css      eobj90=eo90+de90
Css      sobj90=so90+ds90
Css      dam90=SMITH( dld90,sobj90,so90,eobj90,eo90,totdam90,nrev)
      if(dld90.eq.0.)then
        write(6,*)"#Error: 1350:dld90=0 lobj90,climL90(nptc90)= ",
     &            lobj90,climL90(nptc90),nrev
      endif
Cvers1            call getCracks(iret,dld90,dam90)
      jpoint=dld90/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,1136)nrev,nblk,nact,dld90,deltaKmax
       write(6,1136)nrev,nblk,nact,dld90,deltaKmax
       go to 9000  !stop
      endif
      dam90=discDadn(jpoint)/2.0
      dtotdam90=dtotdam90+dble(dam90)
c     Enter the rev in the P.D. list
      nptt90=nptt90+1
      tlimL90(nptt90)=lobj90
Css      tlstr90(nptt90)=eobj90
Css      tlsts90(nptt90)=sobj90
      tldam90(nptt90)   =dam90
      tltotCrk90(nptt90)=dtotdam90
      itlnrev90(nptt90) =nrev
      go to 5000  ! Ramp is done go to 00 code

C     Deformation is occurring on the monotonic curve again.
 1500 continue
      dld90=abs(lobj90)
Css      de90=FLD(dld90*2.0,nrev)
Css      ds90=DET(de90,nrev)
Css      eobj90=de90/2.0
Css      sobj90=ds90/2.0
c     Subtract damage of previous use of monotonic curve (=0 in cyc )
      dtotdam90=dtotdam90-dble(tldam90(1) )
      go to 4000

C     A loop is being closed, count the remaining half of the
c     loop and then eliminate the loop.
 1400 continue
      dld90=tlimL90(nptt90)-climL90(nptc90)
Css      dam90=SMITH( (tlimL90(nptt90)-climL90(nptc90)), 
Css     &      tlsts90(nptt90),clsts90(nptc90),
Css     &      tlstr90(nptt90),clstr90(nptc90),totdam90,nrev)
      if(dld90.eq.0.)then
       write(6,*)"#Error:1400:dld90=0 tlimL90(nptt90),climL90(nptc90)=",
     &            tlimL90(nptt90),climL90(nptc90),nrev
       goto 9000 !stop
      endif
Cvers1            call getCracks(iret,dld90,dam90)
      jpoint=dld90/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,1136)nrev,nblk,nact,dld90,deltaKmax
       write(6,1136)nrev,nblk,nact,dld90,deltaKmax
       go to 9000  !stop
      endif
      dam90=discDadn(jpoint)/2.0
      dtotdam90=dtotdam90+dble(dam90)
      nptc90=nptc90-1
      if(nptc90.eq.0.)then
       write(6,*)"#Error:1401:nptc90=0 tlimL90(1),climL90(1),nrev=",
     &            tlimL90(1),climL90(1),nrev
       goto 9000 !stop
      endif
C     Subtract the old half cycle damage of the Re-incurred
c     stress-strain path.
      dtotdam90=dtotdam90-dble(tldam90(nptt90) )
      nptt90=nptt90-1
c     Reset the local stress-strain origin.
Css      eo90=clstr90(nptc90)
Css      so90=clsts90(nptc90)
      ldo90=climL90(nptc90)
      go to 1100

C*****  Going Down, Compressive Direction ****************************

C     Are we on the monotonic curve?
 2100 if(nptc90 .eq. 0) go to 2500

c     No. Has a exceedence  occurred?
 2110 if(lobj90 .lt. climL90(nptc90)) go to 2120

c     Is this Same as previous amplitude?
 2130 if(lobj90 .eq. climL90(nptc90) .and. nptc90 .ne. 1) go to 2135
      go to 2350

c     Is a loop being closed without the monotonic?
 2120 if(nptc90 .ne. 1) go to 2400

c     Is closure in connection  with the monotonic?
 2150 if(nptt90 .eq. 2) go to 2170

c     Check for impossible
 2160 if(nptt90 .eq. 1) go to 2165
      idump=2160
      go to 9999

C     Same load level as previous level.
 2135 continue
Css      dam90=SMITH( (ldo90-lobj90),tlsts90(nptt90),clsts90(nptc90),
Css     &      tlstr90(nptt90),clstr90(nptc90),totdam90,nrev)
      dld90=ldo90-lobj90
      if(dld90.eq.0.)then
       write(6,*)"#Error:2135:dld90=0 ldo90,lobj90=",
     &            ldo90,lobj90,nrev
      endif
Cvers1            call getCracks(iret,dld90,dam90)
      jpoint=dld90/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,1136)nrev,nblk,nact,dld90,deltaKmax
       write(6,1136)nrev,nblk,nact,dld90,deltaKmax
       go to 9000  !stop
      endif
      dam90=discDadn(jpoint)/2.0
      dtotdam90=dtotdam90+dble(dam90)
c     The closed loop is erased and the point of rev. is already there
      nptt90=nptt90-1
Css      eobj90=clstr90(nptc90)
Css      sobj90=clsts90(nptc90)
      cldam90(nptc90)   =dam90
      cltotCrk90(nptc90)=dtotdam90
      iclnrev90(nptc90) =nrev
      go to 5000  ! Ramp is done go to 00 code

C     An unmatched 1/2 cycle is being forgotten and a return to the
c     monotonic curve is occurring. Count the unmatched 1/2 cycle.
 2165 continue
Css      dam90=SMITH( (tlimL90(1)-climL90(1)),tlsts90(1),clsts90(1),
Css     &        tlstr90(1),clstr90(1),totdam90,nrev)
      dld90=tlimL90(1)-climL90(1)
      if(dld90.eq.0.)then
       write(6,*)"#Error:2165:dld90=0 tlimL90(1),climL90(1)=",
     &            tlimL90(1),climL90(1),nrev
      endif
Cvers1            call getCracks(iret,dld90,dam90)
      jpoint=dld90/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,1136)nrev,nblk,nact,dld90,deltaKmax
       write(6,1136)nrev,nblk,nact,dld90,deltaKmax
       go to 9000  !stop
      endif
      dam90=discDadn(jpoint)/2.0
      dtotdam90=dtotdam90+dble(dam90)
      nptc90=0
      nptt90=0
      go to 2500

C     A loop is being closed and a return to the monotonic
c     curve is occurring.  Damage is the same as the other half of
c     the cycle being closed.
 2170 continue
Css      dam90=SMITH( (tlimL90(2)-climL90(1)),tlsts90(2),
Css     &       clsts90(1),tlstr90(2),clstr90(1),totdam90,nrev)
      dld90=tlimL90(2)-climL90(1)
      if(dld90.eq.0.)then
       write(6,*)"#Error:2170:dld90=0 tlimL90(2),climL90(1)=",
     &            tlimL90(2),climL90(1),nrev
      endif
Cvers1            call getCracks(iret,dld90,dam90)
      jpoint=dld90/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,1136)nrev,nblk,nact,dld90,deltaKmax
       write(6,1136)nrev,nblk,nact,dld90,deltaKmax
       go to 9000  !stop
      endif
      dam90=discDadn(jpoint)/2.0
      dtotdam90=dtotdam90+dble(dam90)
      nptc90=0
      nptt90=0
      go to 2500

C     A new entry in the P.D. list is being made.
 2350 continue
      dld90=abs(lobj90-tlimL90(nptt90))
Css      de90=FLD(dld90,nrev)
Css      ds90=DET(de90,nrev)
Css      eobj90=eo90-de90
Css      sobj90=so90-ds90
Css      dam90=SMITH(dld90,so90,sobj90,eo90,eobj90,totdam90,nrev)
      if(dld90.eq.0.)then
       write(6,*)"#Error:2350:dld90=0 lobj90,tlimL90(nptt90)=",
     &            lobj90,tlimL90(nptt90),nrev
      endif
Cvers1            call getCracks(iret,dld90,dam90)
      jpoint=dld90/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,1136)nrev,nblk,nact,dld90,deltaKmax
       write(6,1136)nrev,nblk,nact,dld90,deltaKmax
       go to 9000  !stop
      endif
      dam90=discDadn(jpoint)/2.0
      dtotdam90=dtotdam90+dble(dam90)
      nptc90=nptc90+1
      if(jpoint.gt.ndiscMax)then
       write(0,1136)nrev,nblk,nact,dld90,deltaKmax
       write(6,1136)nrev,nblk,nact,dld90,deltaKmax
       go to 9000  !stop
      endif
      climL90(nptc90)=lobj90
Css      clstr90(nptc90)=eobj90
Css      clsts90(nptc90)=sobj90
      cldam90(nptc90)   =dam90
      cltotCrk90(nptc90)=dtotdam90
      iclnrev90(nptc90) =nrev
      go to 5000  ! Ramp is done go to 00 code

C     Deformation is occurring on the monotonic curve again. --------
 2500 continue
      dld90=abs(lobj90)
Css      de90=FLD(dld90*2.0,nrev)
Css      ds90=DET(de90,nrev)
Css      eobj90=-de90/2.0
Css      sobj90=-ds90/2.0
c     Subtract damage of previous use of monotonic curve (=0 in cyc )
      dtotdam90=dtotdam90 - dble(tldam90(1) )

C     Add the present damage.  Both Tens. and Comp. comes here.
 4000 continue
Css      dsx90=abs(sobj90)
Css      dex90=abs(eobj90)
C     dsx and dex are amplitudes
C?    dsamp=dsx/2.0
C?    deamp=dex/2.0
C?      The above was probably done to reduce Monotonic damage? or
C?      to solve the question of what is a monot. half cycle?  is it
C?      a range  or an amplitude?
C     Counting damage for monotonic curve usage is probably not a good idea.
C     For example, what if monot. usage is only on compression side?
Css      dsamp90=dsx90
Css      deamp90=dex90
Css      dam90= SMITH(dld90,dsamp90,-dsamp90,deamp90,-deamp90,
Css     &       totdam90,nrev)
      if(dld90.eq.0.)then
        write(6,*)"#Error: 4000:dld90=0 lobj90= ",
     &            lobj90,nrev
      endif
Cvers1            call getCracks(iret,dld90,dam90)
      jpoint=dld90/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,1136)nrev,nblk,nact,dld90,deltaKmax
       write(6,1136)nrev,nblk,nact,dld90,deltaKmax
       go to 9000  !stop
      endif
      dam90=discDadn(jpoint)/2.0
      dtotdam90=dtotdam90+dble(dam90)
c     Set the appropriate push-down list arrays for monotonic.
      climL90(1)=-abs(lobj90)
      tlimL90(1)=abs(lobj90)
      nptt90=1
      nptc90=1
Css      tlstr90(1) =abs(eobj90)
Css      clstr90(1) =-abs(eobj90)
Css      tlsts90(1) =abs(sobj90)
Css      clsts90(1) =-abs(sobj90)
      tldam90(1)   =dam90
      tltotCrk90(1)=dtotdam90
      itlnrev90(1) =nrev
      cldam90(1)   =dam90
      cltotCrk90(1)=dtotdam90
      iclnrev90(1) =nrev
      
      go to 5000    ! half cycle is done, go to  00 code

C     A loop is being closed, count the remaining half of the
c     loop and then eliminate the loop.
 2400 continue
Css      dam90=SMITH( (tlimL90(nptt90)-climL90(nptc90)), 
Css     &       tlsts90(nptt90),clsts90(nptc90),
Css     &       tlstr90(nptt90),clstr90(nptc90),totdam90,nrev)
      dld90=tlimL90(nptt90)-climL90(nptc90)
      if(dld90.eq.0.)then
       write(6,*)"#Error:2400:dld90=0 tlimL90(nptt90),climL90(nptc90)=",
     &            tlimL90(nptt90)-climL90(nptc90),nrev
      endif
Cvers1            call getCracks(iret,dld90,dam90)
      jpoint=dld90/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,1136)nrev,nblk,nact,dld90,deltaKmax
       write(6,1136)nrev,nblk,nact,dld90,deltaKmax
       go to 9000  !stop
      endif
      dam90=discDadn(jpoint)/2.0
      dtotdam90=dtotdam90+dble(dam90)
      nptt90=nptt90-1
C     Subtract the old half cycle damage of the Re-incurred
c     stress-strain path.
      dtotdam90=dtotdam90-dble(cldam90(nptc90) )
      nptc90=nptc90-1
c     Reset the local stress-strain origin.
Css      so90=tlsts90(nptt90)
Css      eo90=tlstr90(nptt90)
      ldo90=tlimL90(nptt90)
      go to 2100     !    continue the ramp.



C============= 00 deg  P.D. List  segment.=======================
C     this segment needs to be able to run on its own.   User may elect
C     shut off  the  90 deg   model. (??) for some reason.
 5000 continue


33000 continue  ! =================Top of 00 Cycling loop====================
Css      ldo00=lobj00
Css      eo00=eobj00
Css      so00=sobj00
      
      
cccccccccccccccccccccccccccccccccccccccccccccc  Block Repeat code not needed here

33001 continue
C     lobj00 and ld00 have been computed at top of overall loop
      dld00=abs(lobj00-ldo00)
Cdebug      write(6,*)"#dld00,lobj00,ldo00=",dld00,lobj00,ldo00,nrev

C     Going up or down ?
      if(lobj00 .lt. ldo00) go to 32100

C************ Going UP,  Tensile Direction **************************
C     Are we on the monotonic curve?
31100 if(nptt00 .eq. 0) go to 31500
c     No. Has a exceedence  occurred?
31110 if(lobj00 .gt. tlimL00(nptt00)) go to 31120

c     Is this Same as previous amplitude?
31130 if(lobj00 .eq. tlimL00(nptt00) .and. nptt00 .ne. 1) go to 31135
      go to 31350

c     Is a loop being closed without the monotonic?
31120 if(nptt00 .ne. 1) go to 31400

c     Is closure in connection  with the monotonic?
31150 if(nptc00 .eq. 2) go to 31170

c     Check for impossible
31160 if(nptc00 .eq. 1) go to 31165
      idump=31160
      go to 9999

C     Same load level as previous level.
31135 continue
Css      dam00=SMITH( (lobj00-ldo00),tlsts00(nptt00),clsts00(nptc00),
Css     &            tlstr00(nptt00),clstr00(nptc00),totdam00,nrev)
      dld00=lobj00-ldo00
      if(dld00.eq.0.)then
        write(6,*)"#Error: 31135:dld00=0 lobj00,ldo00= ",
     &            lobj00,ldo00,nrev
      endif
Cvers1            call getCracks(iret,dld00,dam00)
      jpoint=dld00/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,31136)nrev,nblk,nact,dld00,deltaKmax
       write(6,31136)nrev,nblk,nact,dld00,deltaKmax
31136  format("#Error: deltaK00.gt.deltaKmax: nrev=",i9,
     &       " nblk= ",i6," nact= ",i6,
     &       " dld00= ",e14.7," deltaKmax= ",e14.7)
       goto 9000  !stop
      endif
      dam00=discDadn(jpoint)/2.0
      dtotdam00=dtotdam00+dble(dam00)
      nptc00=nptc00-1
C     Double damage count error here in versions before July15 2013

c     The closed loop is erased and the point of rev. is already there
Css      eobj00=tlstr00(nptt00)
Css      sobj00=tlsts00(nptt00)
      tldam00(nptt00)=dam00
      tltotCrk00(nptt00)=dtotdam00
      itlnrev00(nptt00) =nrev
      go to 3000  ! Ramp is done go get next ramp

C     An unmatched 1/2 cycle is being forgotten and a return to the 
c     monotonic curve is occurring. Count the unmatched 1/2 cycle.
31165 continue
Css      dam00=SMITH ( (tlimL00(1)-climL00(1)), tlsts00(1), clsts00(1),
Css     &         tlstr00(1),clstr00(1),totdam00,nrev)
      dld00=tlimL00(1)-climL00(1)
      if(dld00.eq.0.)then
        write(6,*)"#Error: 31165:dld00=0 tlimL00(1),climL00(1)= ",
     &            tlimL00(1),climL00(1),nrev
      endif
Cvers1            call getCracks(iret,dld00,dam00)
      jpoint=dld00/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,31136)nrev,nblk,nact,dld00,deltaKmax
       write(6,31136)nrev,nblk,nact,dld00,deltaKmax
       go to 9000  !stop
      endif
      dam00=discDadn(jpoint)/2.0
      dtotdam00=dtotdam00+dble(dam00)
      nptc00=0
      nptt00=0
      go to 31500 !  go and reset the monotonic entry.

C     A loop is being closed and a return to the monotonic 
c     curve is occurring.  Damage is the same as the other half of
c     the cycle being closed.
31170 continue
Css      dam00=SMITH( (tlimL00(1)-climL00(2)),
Css     &    tlsts00(1),clsts00(2),
Css     &    tlstr00(1),clstr00(2), totdam00,nrev)
      dld00=tlimL00(1)-climL00(2)
      if(dld00.eq.0.)then
        write(6,*)"#Error: 31170:dld00=0 tlimL00(1),climL00(2)= ",
     &            tlimL00(1),climL00(2),nrev
      endif
Cvers1            call getCracks(iret,dld00,dam00)
      jpoint=dld00/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,31136)nrev,nblk,nact,dld00,deltaKmax
       write(6,31136)nrev,nblk,nact,dld00,deltaKmax
       go to 9000  !stop
      endif
      dam00=discDadn(jpoint)/2.0
      dtotdam00=dtotdam00+dble(dam00)
c     Eliminate the closed loop.
      nptc00=0
      nptt00=0
      go to 31500

C     A new entry in the P.D. list is being made.
31350 continue
      dld00=abs(lobj00-climL00(nptc00))
Css      de00=FLD(dld00,nrev)
Css      ds00=DET(de00,nrev)
Css      eobj00=eo00+de00
Css      sobj00=so00+ds00
Css      dam00=SMITH( dld00,sobj00,so00,eobj00,eo00,totdam00,nrev)
      if(dld00.eq.0.)then
        write(6,*)"#Error: 31350:dld00=0 lobj00,climL00(nptc00)= ",
     &            lobj00,climL00(nptc00),nrev
      endif
Cvers1            call getCracks(iret,dld00,dam00)
      jpoint=dld00/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,31136)nrev,nblk,nact,dld00,deltaKmax
       write(6,31136)nrev,nblk,nact,dld00,deltaKmax
       go to 9000  !stop
      endif
      dam00=discDadn(jpoint)/2.0
      dtotdam00=dtotdam00+dble(dam00)
c     Enter the rev in the P.D. list
      nptt00=nptt00+1
      tlimL00(nptt00)=lobj00
Css      tlstr00(nptt00)=eobj00
Css      tlsts00(nptt00)=sobj00
      tldam00(nptt00)=dam00
      tltotCrk00(nptt00)=dtotdam00
      itlnrev00(nptt00) =nrev
      go to 3000  ! Ramp is done go get next ramp

C     Deformation is occurring on the monotonic curve again.
31500 continue
      dld00=abs(lobj00)
Css      de00=FLD(dld00*2.0,nrev)
Css      ds00=DET(de00,nrev)
Css      eobj00=de00/2.0
Css      sobj00=ds00/2.0
c     Subtract damage of previous use of monotonic curve (=0 in cyc )
      dtotdam00=dtotdam00-dble(tldam00(1) )
      go to 34000

C     A loop is being closed, count the remaining half of the
c     loop and then eliminate the loop.
31400 continue
      dld00=tlimL00(nptt00)-climL00(nptc00)
Css      dam00=SMITH( (tlimL00(nptt00)-climL00(nptc00)), 
Css     &       tlsts00(nptt00),clsts00(nptc00),
Css     &       tlstr00(nptt00),clstr00(nptc00),totdam00,nrev)
Cvers1            call getCracks(iret,dld00,dam00)
      if(dld00.eq.0.)then
      write(6,*)"#Error:31400:dld00=0 tlimL00(nptt00),climL00(nptc00)=",
     &            tlimL00(nptt00),climL00(nptc00),nrev
      endif
      jpoint=dld00/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,31136)nrev,nblk,nact,dld00,deltaKmax
       write(6,31136)nrev,nblk,nact,dld00,deltaKmax
       go to 9000  !stop
      endif
      dam00=discDadn(jpoint)/2.0
      dtotdam00=dtotdam00+dble(dam00)
      nptc00=nptc00-1
      if(nptc00 .eq. 0)then
        write(6,*)"#Error:31401:nptc00=0 tlimL00(1),climL00",
     &            "(1)=",tlimL00(1),climL00(1),nrev
        goto 9000 !bomb out with results
      endif
C     Subtract the old half cycle damage of the Re-incurred
c     stress-strain path.
      dtotdam00=dtotdam00-dble(tldam00(nptt00) )
      nptt00=nptt00-1
c     Reset the local stress-strain origin.
Css      eo00=clstr00(nptc00)
Css      so00=clsts00(nptc00)
      ldo00=climL00(nptc00)
      go to 31100

C*****  Going Down, Compressive Direction ****************************

C     Are we on the monotonic curve?
32100 if(nptc00 .eq. 0) go to 32500

c     No. Has a exceedence  occurred?
32110 if(lobj00 .lt. climL00(nptc00)) go to 32120

c     Is this Same as previous amplitude?
32130 if(lobj00 .eq. climL00(nptc00) .and. nptc00 .ne. 1) go to 32135
      go to 32350

c     Is a loop being closed without the monotonic?
32120 if(nptc00 .ne. 1) go to 32400

c     Is closure in connection  with the monotonic?
32150 if(nptt00 .eq. 2) go to 32170

c     Check for impossible
32160 if(nptt00 .eq. 1) go to 32165
      idump=32160
      go to 9999

C     Same load level as previous level.
32135 continue
Css      dam00=SMITH( (ldo00-lobj00),tlsts00(nptt00),clsts00(nptc00),
Css     &      tlstr00(nptt00),clstr00(nptc00),totdam00,nrev)
      dld00=ldo00-lobj00
      if(dld00.eq.0.)then
      write(6,*)"#Error:32135:dld00=0 ldo00,lobj00=",
     &            ldo00,lobj00,nrev
      endif
Cvers1            call getCracks(iret,dld00,dam00)
      jpoint=dld00/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,31136)nrev,nblk,nact,dld00,deltaKmax
       write(6,31136)nrev,nblk,nact,dld00,deltaKmax
       go to 9000  !stop
      endif
      dam00=discDadn(jpoint)/2.0
      dtotdam00=dtotdam00+dble(dam00)
c     The closed loop is erased and the point of rev. is already there
      nptt00=nptt00-1
Css      eobj00=clstr00(nptc00)
Css      sobj00=clsts00(nptc00)
      cldam00(nptc00)=dam00
      cltotCrk00(nptc00)=dtotdam00
      iclnrev00(nptc00) =nrev
      go to 3000  ! Ramp is done go get next ramp

C     An unmatched 1/2 cycle is being forgotten and a return to the
c     monotonic curve is occurring. Count the unmatched 1/2 cycle.
32165 continue
Css      dam00=SMITH( (tlimL00(1)-climL00(1)),tlsts00(1),clsts00(1),
Css     &              tlstr00(1),clstr00(1),totdam00,nrev)
      dld00=tlimL00(1)-climL00(1)
      if(dld00.eq.0.)then
      write(6,*)"#Error:32165:dld00=0 tlimL00(1),climL00(1)=",
     &           tlimL00(1),climL00(1),nrev
      endif
Cvers1            call getCracks(iret,dld00,dam00)
      jpoint=dld00/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,31136)nrev,nblk,nact,dld00,deltaKmax
       write(6,31136)nrev,nblk,nact,dld00,deltaKmax
       go to 9000  !stop
      endif
      dam00=discDadn(jpoint)/2.0
      dtotdam00=dtotdam00+dble(dam00)
      nptc00=0
      nptt00=0
      go to 32500

C     A loop is being closed and a return to the monotonic
c     curve is occurring.  Damage is the same as the other half of
c     the cycle being closed.
32170 continue
Css      dam00=SMITH( (tlimL00(2)-climL00(1)),tlsts00(2),
Css     &       clsts00(1),tlstr00(2),clstr00(1),totdam00,nrev)
      dld00=tlimL00(2)-climL00(1)
      if(dld00.eq.0.)then
      write(6,*)"#Error:32170:dld00=0 tlimL00(2),climL00(1)=",
     &           tlimL00(2),climL00(1),nrev
      endif
Cvers1            call getCracks(iret,dld00,dam00)
      jpoint=dld00/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,31136)nrev,nblk,nact,dld00,deltaKmax
       write(6,31136)nrev,nblk,nact,dld00,deltaKmax
       go to 9000  !stop
      endif
      dam00=discDadn(jpoint)/2.0
      dtotdam00=dtotdam00+dble(dam00)
      nptc00=0
      nptt00=0
      if(jpoint.gt.ndiscMax)then
       write(0,31136)nrev,nblk,nact,dld00,deltaKmax
       write(6,31136)nrev,nblk,nact,dld00,deltaKmax
       go to 9000  !stop
      endif
      go to 32500

C     A new entry in the P.D. list is being made.
32350 continue
      dld00=abs(lobj00-tlimL00(nptt00))
Css      de00=FLD(dld00,nrev)
Css      ds00=DET(de00,nrev)
Css      eobj00=eo00-de00
Css      sobj00=so00-ds00
Css      dam00=SMITH(dld00,so00,sobj00,eo00,eobj00,totdam00,nrev)
      if(dld00.eq.0.)then
      write(6,*)"#Error:32350:dld00=0 lobj00,tlimL00(nptt00)=",
     &           lobj00,tlimL00(nptt00),nrev
      endif
Cvers1            call getCracks(iret,dld00,dam00)
      jpoint=dld00/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,31136)nrev,nblk,nact,dld00,deltaKmax
       write(6,31136)nrev,nblk,nact,dld00,deltaKmax
       go to 9000  !stop
      endif
      dam00=discDadn(jpoint)/2.0
      dtotdam00=dtotdam00+dble(dam00)
      nptc00=nptc00+1
      climL00(nptc00)=lobj00
Css      clstr00(nptc00)=eobj00
Css      clsts00(nptc00)=sobj00
      cldam00(nptc00)=dam00
      cltotCrk00(nptc00)=dtotdam00
      iclnrev00(nptc00) =nrev
      go to 3000  ! Ramp is done go get next ramp

C     Deformation is occurring on the monotonic curve again. --------
32500 continue
      dld00=abs(lobj00)
Css      de00=FLD(dld00*2.0,nrev)
Css      ds00=DET(de00,nrev)
Css      eobj00=-de00/2.0
Css      sobj00=-ds00/2.0
c     Subtract damage of previous use of monotonic curve (=0 in cyc )
      dtotdam00=dtotdam00 - dble(tldam00(1) )

C     Add the present damage.  Both Tens. and Comp. comes here.
34000 continue
Css      dsx00=abs(sobj00)
Css      dex00=abs(eobj00)
C     dsx and dex are amplitudes
C?    dsamp=dsx/2.0
C?    deamp=dex/2.0
C?      The above was probably done to reduce Monotonic damage? or
C?      to solve the question of what is a monot. half cycle?  is it
C?      a range  or an amplitude?
C     Counting damage for monotonic curve usage is probably not a good idea.
C     For example, what if monot. usage is only on compression side?
Css      dsamp00=dsx00
Css      deamp00=dex00
Css      dam00= SMITH(dld00,dsamp00,-dsamp00,deamp00,-deamp00,totdam00,
Css     &             nrev)
      if(dld00.eq.0.)then
        write(6,*)"#Error: 34000:dld00=0 lobj00= ",
     &            lobj00,nrev
      endif
Cvers1            call getCracks(iret,dld00,dam00)
      jpoint=dld00/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,31136)nrev,nblk,nact,dld00,deltaKmax
       write(6,31136)nrev,nblk,nact,dld00,deltaKmax
       go to 9000  !stop
      endif
      dam00=discDadn(jpoint)/2.0
      dtotdam00=dtotdam00+dble(dam00)
c     Set the appropriate push-down list arrays for monotonic.
      climL00(1)=-abs(lobj00)
      tlimL00(1)=abs(lobj00)
      nptt00=1
      nptc00=1
Css      tlstr00(1) =abs(eobj00)
Css      clstr00(1) =-abs(eobj00)
Css      tlsts00(1) =abs(sobj00)
Css      clsts00(1) =-abs(sobj00)
      tldam00(1) =dam00
      tltotCrk00(1)=dtotdam00
      itlnrev00(1) =nrev
      cldam00(1) =dam00
      cltotCrk00(1)=dtotdam00
      iclnrev00(1) =nrev

      go to 3000    !go back to begin of overall program cycle loop

C     A loop is being closed, count the remaining half of the
c     loop and then eliminate the loop.
32400 continue
      dld00=tlimL00(nptt00)-climL00(nptc00)
Css      dam00=SMITH( (tlimL00(nptt00)-climL00(nptc00)), 
Css     &       tlsts00(nptt00),clsts00(nptc00),
Css     &       tlstr00(nptt00),clstr00(nptc00),totdam00,nrev)
      if(dld00.eq.0.)then
      write(6,*)"#Error:32400:dld00=0 tlimL00(nptt00),climL00(nptc00)=",
     &           tlimL00(nptt00),climL00(nptc00),nrev
      endif
Cvers1            call getCracks(iret,dld00,dam00)
      jpoint=dld00/discDKinterval+1
      if(jpoint.gt.ndiscMax)then
       write(0,31136)nrev,nblk,nact,dld00,deltaKmax
       write(6,31136)nrev,nblk,nact,dld00,deltaKmax
       go to 9000  !stop
      endif
      dam00=discDadn(jpoint)/2.0
      dtotdam00=dtotdam00+dble(dam00)
      nptt00=nptt00-1
C     Subtract the old half cycle damage of the Re-incurred
c     stress-strain path.
      dtotdam00=dtotdam00-dble(cldam00(nptc00) )
      nptc00=nptc00-1
c     Reset the local stress-strain origin.
Css      so00=tlsts00(nptt00)
Css      eo00=tlstr00(nptt00)
      ldo00=tlimL00(nptt00)
      go to 32100     !    continue the ramp.


 9000 continue
C      write out the -ve number of the last rec.  that was written.
C      All the other variables in this rec are endof test values.
       ndummy=-nrecord  !make -ve to make it unique.
       xdummy=0.
       write(60,rec=1)ndummy,xdummy,xdummy,nblk,nact,
     &             lobj90,lobj00,xMm90,xMb90,xMm00,xMb00,
     &             xMkm90,xMkb90,xMkm00,xMkb00,xfw,
     &             stsMembrane,stsBending
      close(unit=60)

       write(0,9050)nrev,totdam90,totdam00,nblk,nact
       write(6,9050)nrev,totdam90,totdam00,nblk,nact
 9050  format("#Last: nrev= ",i10," a= ",e14.7," c= ",e14.7,
     &        "   nblk= ",i10," nact= ",i10/)
      stop

 9999 write(6,9998) idump
 9998 format("# *** Error: near statement label no. ",i5/)
      stop
      end

C===============================================================
      SUBROUTINE getCracks(iret,dld,dam)
C     s/r to take dld, the deltaK range, and compute dam= crack increment
C     from the tables of  dadn vs deltak.
C     The table used is a log  version of dadn vs deltaK,  and desired 
C     points are interpolated using the log-log  points of the table.

      real*4  deltaK(50),dadn(50),logdeltaK(50),logdadn(50),
     &        logdiffdK(50),logdiffdadn(50)
      logical debugDadn
      common/DADN/ deltaK,dadn,logdeltaK,logdadn,logdiffdK,logdiffdadn,
     &             ndadn,maxdadn,debugDadn

C     Note that this routine is not called each reversal. The simulation
C     uses the damage tables to compute damage, normally.

      iret=0  ! return and error no. if non-zero
      if(dld.le.0.)then
        write(0,100)dld   !  This should not happen, try to compensate.
        write(6,100)dld
  100   format("#Error: call to getCracks() deltaK .le. 0,  deltaK=",
     &         e14.7)
        dam=0.
        iret=-1
        return
      endif
      dldlog=ALOG10(dld)

      n=1   ! point to the first table point.
      if(dldlog .lt. logdeltaK(n) )then  ! smaller than the first point?
C       Assume we are below the threshold
        dam=0
        return
      endif
C     Ok, we are equal to or above the first point
  300 continue
      n=n+1
      if(n.gt.ndadn)then
        write(0,350)dld,deltaK(n-1)
        write(6,350)dld,deltaK(n-1)
  350   format("#Fracture: getCracks():  deltaK = ",e14.7/
     &        "# is bigger than largest entry in dadn table: ",e14.7)
        iret=999
        return  !return to a stop. Must write last binary record.
      endif

      if(dldlog .gt. logdeltaK(n))go to 300  ! we are in the desired interval

C     No?  Ok, we are below the n data point, time to interpolate
      frac=(dldlog-logdeltaK(n-1))/logdiffdk(n)
      dam=10**(frac*logdiffdadn(n) + logdadn(n-1) )
C     Divide by 2 to make it per 1/2 cycle
      dam=dam/2.0
      return
      end
      

C================================================================
      REAL FUNCTION XKP(L,nrev)
C***** Compute Stress concentration due to :
C      (A) Notch effect
C      (B) Finite width correction

      SAVE
      real  L,fwks(100),fwkl(100)
      logical stabl
      common /STAB/ stabl
      stabl=.false.
      if(nrev .eq. 0)go to 100
      if(L .ge. xLong) go to 20
      if(L .ge. xLmin) go to 10

c     Short crack, interpolate with 'fwks'
      ip=ifix(L/xinc)+1
      xlast=(ip-1)*xinc
      ipnext=ip+1
      xkp=fwks(ip)+((L-xlast)/xinc) * (fwks(ipnext)-fwks(ip))
      if(xkp .lt. xkinit)stabl=.true.
      return

C     long crack, use "fwkl"
   10 ip=ifix((L-xLmin)/x2inc)+1
      xlast=xLmin+(ip-1)*x2inc
      ipnext=ip+1
      xkp= fwkl(ip)+((L-xlast)/x2inc)*(fwkl(ipnext)-fwkl(ip))
      if(xkp .lt. xkinit) stabl=.true.
      return

   20 write(6,117)L,nrev
      write(0,117)L,nrev
  117 format("# Crack too Long, L= ",E14.7," nrev=",I10)
      xkp=999.0
      return

c     Initilize prior to program run
  100 write(6,102)
  102 format("#Enter six constants A0, A1, ...A5 for K' polyn")
      read(5,*) a0,a1,a2,a3,a4,a5
  103 write(6,104) a0,a1,a2,a3,a4,a5
  104 format("#" 3(1x,e14.7)/3(1x,e14.7)/"#   OK? (1=yes,0=no):")
      read(5,*,err=103)iyes
      if(iyes .ne. 1) go to 100

  105 write(6,106)
  106 format(" Enter B(1/2 plate width), and D(1/2 notch width)")
      read(5,*,err=105)B,D
      write(6,*)B,D
      
  110 write(6,111)
  111 format("#Enter Max. L/D value of K' polyn. :")
      read(5,*,err=110) xLdm
      write(6,*)xLdm

C     Commence  fw*K' computation  '
      xLo1=xLdm*D
      xinc=xLo1/100.0
      xL1=0.0
      write(6,116) B,D,xLo1,xLdm
  116 format("# B= ",f6.4," D= ",f6.4,/"# Short crack up to L= ",f7.5,
     &  " at L/D max= ",f7.4
     &  //"#FWK #     L     L/D      K'      FW      FW*K'short")
      do 200 i=1,100
        xLd=xL1/D
        if(xLd .eq. 0)then
          sks=a0
        else 
          sks=a0-a1*xLd+a2*xLd**2 -a3*xLd**3 +a4*xLd**4 -A5*xLd**5
        endif
        fw=sqrt(1.0/(cos(3.141593*(xL1+D)/(2.0*B) )))
        fwks(i)=sks*fw
        write(6,114) xL1, xLd,sks, fw, fwks(i)
  114   format("#FWK ",f8.5,1x,f6.3,1x,f9.3,1x,f8.5,1x,f9.3)
C       Increment cracks
        xL1=xL1+xinc
  200 continue

      x2inc=(B-xLo1-D+xinc)/100.0
c     Long crack calcs. overlap short by length of xLo1
      xLmin=xLo1-xinc
      xL2=xLmin
      write(6,217)
  217 format("#FWK #  L      L/D    L/B     K'    FW    FW*K'long")
      do 210 i=1,100
C       Compute larger intervals (long cracks)
        xLd2=xL2/D
        xLb=xL2/B
        sks2=sqrt( (xL2+D)/xL2)
        fw2=sqrt(1.0/(cos(3.141593*(xL2+D)/(2.0*B) )))
        fwkl(i)=sks2*fw2
        write(6,219)  xL2,xLd2,xLb,sks2,fw2,fwkl(i)
  219   format("#FWK ",F8.5,5(1x,f6.3))
C       Increment cracks
        xL2=xL2+x2inc
  210 continue

      xlong=xL2-x2inc*2.0
      write(6,115)
  115 format("# Center crack & Notch assumed !"/"    Enter xkinit :")
      read(5,*)xkinit
      xkp=0.0
      return
      end


C================================================================
      REAL FUNCTION SMITH( skfw,smax,smin,emax,emin,crackL,nrev)
C      Changed mean stress correction aug 21/78
C      The function SMITH= CRACK Increment per Reversal
C     skfw = delta S * K'' * FW  
C     smax,smin = max and min local stress of hysteresis loop
c     emax,emin = max and min local strain
c     crackL = present crack length
c     nrev = no. of reversals. =0 causes initilization of function

      SAVE
      integer iovers
      logical stabl
      common/STAB/ stabl
      smith=0.
      if(nrev .eq.0) go to 200
      if(smax .le. 0) return

      de=emax-emin
      ds=smax-smin
      samp=ds/2.0

c     Mean stress code
      if( .not. stabl) go to 10
c     Consider the strain range of the portion of the loop that is 
c     above zero load:
      if(smin .lt. 0.0) de=de+smin/Emod
      xsmin=smin
      if(smin .lt. 0.0) xsmin=0.0
      dk=emod *de*2 * sqrt(smax/(smax-xsmin))
      go to 11

C     Non-stable, compressive plasticity accounted for
   10 dk= emod * de * sqrt(smax/samp)
   11 dk = dk * sqrt(3.141593 * (crackL+crack0))

C     Check for plastic zone size correction
      if(ds .le. Z) dk = dk * sqrt(xk1/(xk1-3.141593 * ds**2))
      if(iovers .eq. 1) go to 50
    5 if( dk .lt. dkth)return
      dko2=dk/2.0
      if(dko2 .ge. xkc)go to 20
      SMITH= xkc* A * (dk-dkth)**xm/(xkc-dk/2.0)
c     Divide by 2 to make it per half cycle or reversal
      SMITH=SMITH/2.0
      return

   20 write(6,103)dko2,xkc,crackl,nrev
  103 format("# Fracture, DK/2= ",f8.3," .GE. Ko= ",f8.3," L, NREV= ",
     &       F8.4,i10)
      SMITH=9999.9
      return

C     Kth Eliminated
   50 continue
      dko2=dk/2.0
      if(dko2 .GE. xkc) go to 20
      SMITH= (A*(dk**xm) )
      SMITH=SMITH/2.0
      return

C     Initilize constants
  200 write(6,101)
  101 format("# Enter E, Kth, Kc, L0,  A, M, K1, Z, iovers  :")
      read(5,*,err=200) emod,dkth,xkc,crack0, A,xm,xk1, z,iovers
      write(6,102) emod,dkth,xkc,crack0, A,xm,xk1, z,iovers
  102 format(1x,f7.0,f6.2, 1x,f5.1,f7.4,E14.7,F5.2,f8.0,f9.0,i3/
     &     "# OK ? (enter 1 or 0):")
      read(5,*,err=200)iyes
      if(iyes.ne.1) go to 200
      return
      end


C================================================================
      REAL FUNCTION FLD(dld,nrev)
C      dld is = FW * K'' * deltaS
c      This function computes the local strain range from the 
c      nominal stress range (or load range)
C         Material: G40.21-50A crack model data. Load=FW*K''*ds June 5/79

      SAVE
      real str(17)/ 0.,0.,0.,  0.0020,0.00285,0.0040,  0.00523,
     &  0.00650, 0.00796, 0.00945, 0.01118, 0.01318, 0.01540,
     &  0.01765, 0.01990, 0.02220, 0.02450/, sinc/20.0/,emod/30000./
      integer non/17/
      if(nrev .eq. 0) go to 50
      if(dld .ge. 320.0) go to 30
      if(dld .gt. 60.0)  go to 20
C     If not then elastic conditions exist
      FLD=dld/emod
      return

C     The nominal Stress-local Strain data exists, comput the local
C     strain by interpolation.
   20 continue
      ipoint=ifix(dld/sinc)+1
      dlast=(ipoint-1)*sinc
   25 ipnext=ipoint+1
      FLD= str(ipoint)+( (dld-dlast)/sinc)*(str(ipnext)-str(ipoint) )
      return

   30 write(6,106)dld,nrev
C     The stress is too large for interpolation.
  106 format("# ***Nominal Stress of ",f7.2," in REV. ",i10," is too"/
     &    T5,"large for interp. using existing data. Equation used."/
     & )
      FLD=3.1475266E-06 * (dld)**1.536107
      return

   50 so=0.0
      write(6,104)
  104 format(//T3,"Nominal Stress - Local Strain Curve"/)
      do 52 i=1,non
         write(6,103) i,so,str(i)
  103    format(T2,i4,f8.2,2x,f8.5)
         so=so+sinc
   52 continue
      FLD=0.0
      return
      end
      

C================================================================
      REAL FUNCTION DET(de,nrev)
C       Compute the local stress range from the local strain range

      SAVE
      integer non/26/
      real sts(26)/0.0, 30.0, 60.0, 76.5, 86.0, 92.2, 97.4, 101.5,
     &    105.7, 109.4, 112.8, 115.5, 117.6, 120.4, 122.8, 124.9,
     &    127.0, 129.0, 131.0, 132.3, 133.6, 134.8, 136.1, 137.8, 
     &    139.0, 140.0/
     &    ,einc/0.0010/, emod/30000.0/

c     Initilize?
      if(nrev .eq. 0) go to 50
c     The stress data exists, compute the local stress by 
c     interpolating between the points.
      if(de .gt. 0.0020) go to 20
c     If not then elastic conditions exist.
      det=emod*de
      return

   20 continue
      if(de .gt. 0.0250) go to 30
c     No?  then interpolate:
      ipoint=ifix(de/einc)+1
      dlast=(ipoint-1)*einc
   25 ipnext=ipoint+1
      det=sts(ipoint) +
     &    ((de-dlast)/einc) * (sts(ipnext)-sts(ipoint))
      return

   30 continue
      write(6,110) de,nrev
  110 format("#*** Strain Rg. of ",f8.5," in REV. ",i10," is too large"/
     &      T5,"for interpolation, Used  DS=A*DE**B equation.")
      det=361.6735*de**0.2572866
      return

   50 continue
      write(6,104)
  104 format(///T5,"# Smooth Specimen Stress-Strain curve"//
     & T8,"STRAIN", T17,"STRESS"/
     & )
      ex=0.
      do 60 i=1,non
         write(6,55)i,ex,sts(i)
   55    format("#SS    "i3,1x,f8.5,1x,f8.1)
         ex=ex+einc
   60 continue

      DET=0.0
      return
      end


C================================================================================
      SUBROUTINE getStress2Strain(Stress,Strain,iexit)
      SAVE
C     Given Stress Ampl., interpolate Strain
C---------------------------------------------------------------------------
C Subroutine from GNU GPL software: fde.uwaterloo.ca/Fde/Calcs/saefcalc1.html
C  Alterations have been made to data storage.

C  Copyright (C) 2000 SAE Fatigue Design and Evaluation Committee
C  This program is free software; you can redistribute it and/or
C  modify it under the terms of the GNU General Public License as
C  published by the Free Software Foundation; either version 2 of the
C  license, or (at your option) any later version.
C
C  This program is distributed in the hope tha it will be useful,
C  but WITHOUT ANY WARRANTY; without even the implied warranty of
C  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
C  GNU General PUblic License for more details.
C
C  You should have received a copy of the GNU General PUblic License
C  along with this program; if not, write to the Free Software
C  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
C  Try also their web site: http://www.gnu.org/copyleft/gpl.html
C---------------------------------------------------------------------------

C  From saefcalc1.f:
C      real StressAmp(250), StrainAmp(250), SelasticAmp(250),
C     &     Lifecycles(250), PlstrainAmp(250), ElstrainAmp(250),
C     &     SigmaxStrainAmp(250)
C      integer ndata
C      real FractureStress,FractureStrain
C      Common/Material/ StressAmp,StrainAmp,SelasticAmp,Lifecycles,
C     &                 PlstrainAmp,ElstrainAmp,SigmaxStrainAmp,
C     &                 ndata,FractureStress,FractureStrain

C     These are used to store the equal spaced Snom. fitted data file.
      real StressAmp(1500), StrainAmp(1500), SnominalAmp(1500)
      integer*4 nmatdata,maxmatdata
C      real FractureStress,FractureStrain,Emod
      logical debugMat
      common/MATERIAL/ StressAmp,StrainAmp,SnominalAmp,
     &      snominalInterval,nmatdata,maxmatdata,debugMat

      iexit=0

C       We are assuming that the data has been sorted to largest life,
C       and thus smallest stress, strain etc, first.
C       If the stress is below the first stress point, then it is below
C       the fatigue limit (the first life value in the table).

      if(Stress .lt. StressAmp(1))then
C       Yes, its below. Assume straight line from (0,0)
        Strain=(Stress/StressAmp(1))*StrainAmp(1)
        return
      endif
      
C     Check if data is above Sigfp
      if(Stress .ge. StressAmp(nmatdata))then
C       The specimen fails in first 1/2 cycle. Damage is >= 1.
        Strain=StrainAmp(nmatdata)
        iexit=1
        return
      endif

C     Ok, the input appears to lie between the two extremes. Lets
C     hunt & peck.  Basically we are going to hunt our way up the stress
C     ladder.  When our point is bigger than the last rung, and smaller than
C     the next rung, we can interpolate.

      do 1000 idat=1,ndata
        if(Stress - StressAmp(idat) ) 100,200,300
C         In-elegant but fast:          -ve  0  +ve
C         When the result is -ve, then the curve point is just above
C         the point we want, and we can interpolate.


  100   continue
C       Our stress is less than the point on the curve, we have arrived
C       Interpolate.  Try log-log interpl.  If we ever get -ve stresses
C       or strains we will definitely have to go to linear interpl.
C     Change log-log interpolation to linear.  We have 1000 points.
        xslope=
     &     (StressAmp(idat) -StressAmp(idat-1))
     &    /(StrainAmp(idat)-StrainAmp(idat-1) )
        C=  (Stress-StressAmp(idat-1) )/xslope
     &          +StrainAmp(idat-1)
C         Strain= 10.0**Clog
        Strain=C
        return

  200   continue
C       The stress is exactly equal to the curve point(idat)
C       There could be a "flat" spot in the stress-strain curve, and
C       thus the next point would have the same stress value. Check
Cbugfix   May2005 : im was not incrementing
        im=idat
  201   im=im+1
        if(Stress .eq. StressAmp(im))then
C         yes, another is equal. is there more?
          go to 201
        endif
C       No, now the (im) point has bigger stress, use the last
C       one that was equal as a match
Cbugfix   May2005 : Should be im-1
        Strain=StrainAmp(im-1)
        return



  300   continue
C       Ok, Point(idat) on the curve is still smaller, keep going
        go to 1000

 1000   continue

        write(0,*)" ERROR:plateWeldflaw:getStress2Strain.endofdoloop"
        iexit=1
C       We should not be here.  Assume fracture strain or largest
        Strain=StrainAmp(nmatdata)
        return
        end


C-================================================================================
      SUBROUTINE getLoad2StressStrain(Sneuber,Stress,Strain,
     &           iexit)
      SAVE
C     Given Load_Amp (could be FEA Stress Ampl.), interpolate Strain &Stress
C---------------------------------------------------------------------------
C Subroutine from GNU GPL software: fde.uwaterloo.ca/Fde/Calcs/saefcalc1.html

C  Copyright (C) 2000 SAE Fatigue Design and Evaluation Committee
C  This program is free software; you can redistribute it and/or
C  modify it under the terms of the GNU General Public License as
C  published by the Free Software Foundation; either version 2 of the
C  license, or (at your option) any later version.
C
C  This program is distributed in the hope tha it will be useful,
C  but WITHOUT ANY WARRANTY; without even the implied warranty of
C  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
C  GNU General PUblic License for more details.
C
C  You should have received a copy of the GNU General PUblic License
C  along with this program; if not, write to the Free Software
C  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
C  Try also their web site: http://www.gnu.org/copyleft/gpl.html
C---------------------------------------------------------------------------

C  From saefcalc1.f:
C      real StressAmp(250), StrainAmp(250), SelasticAmp(250),
C     &     Lifecycles(250), PlstrainAmp(250), ElstrainAmp(250),
C     &     SigmaxStrainAmp(250)
C      integer ndata
C      real FractureStress,FractureStrain
C      Common/Material/ StressAmp,StrainAmp,SelasticAmp,Lifecycles,
C     &                 PlstrainAmp,ElstrainAmp,SigmaxStrainAmp,
C     &                 ndata,FractureStress,FractureStrain

C     Storage for the equal spaced Snom.interval fitted data table in "matfile".
      real StressAmp(1500), StrainAmp(1500), SnominalAmp(1500)
      integer*4 nmatdata,maxmatdata
C      real FractureStress,FractureStrain,Emod
      logical debugMat
      common/MATERIAL/ StressAmp,StrainAmp,SnominalAmp,
     &      snominalInterval,nmatdata,maxmatdata,debugMat

      iexit=0

C       We are assuming that the data has been sorted to largest life,
C       and thus smallest stress, strain etc, first.
C       If the "load", actually = Elastic_local_Stress, is below 
C       the first SelasticAmp point, then it is below
C       the fatigue limit (the first life value in the table).

      if(Sneuber .lt. SnominalAmp(1))then  ! SnominalAmp(1) is usually=0.
C       Yes, its below. Assume straight line from (0,0) t
        Strain=(Sneuber/SnominalAmp(1))*StrainAmp(1)
        Stress=(Sneuber/SnominalAmp(1))*StressAmp(1)
        return
      endif
      
C     Check if data is above Sigfp  or largest point.
C     Assumes: ElasMod= First Stress/ 1st strain
C     If these first points are not on the "elastic" line we could have
C     a problem here, but it shouldnt be too bad (?)

      if(Sneuber .ge. SnominalAmp(nmatdata))then
C       The specimen fails in first 1/2 cycle. Damage is >= 1.
        Strain=StrainAmp(nmatdata)
        Stress=StressAmp(nmatdata)
        write(0,50)Sneuber,SnominalAmp(nmatdata)
        write(6,50)Sneuber,SnominalAmp(nmatdata)
   50   format("#Fracture:getLoad2StressStrain(): Requested Snominal=",
     &  f7.1," Max. value in matfile= ",f7.1," = Fracture")
        iexit=999                   !  this is the only return signal
        return
      endif

C     Ok, the input appears to lie between the two extremes. Lets
C     hunt & peck.  Basically we are going to hunt our way up the stress
C     ladder.  When our point is bigger than the last rung, and smaller than
C     the next rung, we can interpolate.

C     Since the SnominalAmp()  is in equal sized intervals we can jump
C     directly to the two straddle points.
       idat= ifix(Sneuber /snominalInterval)+1

C       Our stress is less than the point on the curve, we have arrived
C       Interpolate.  Try log-log interpl.  If we ever get -ve stresses
C       or strains we will definitely have to go to linear interpl.
C    Since we have about 1000 points, switch to linear interpolation:
        xslope=
     &     ( SnominalAmp(idat) -SnominalAmp(idat-1) )
     &    /( StressAmp(idat)-StressAmp(idat-1) )
        C=  ( Sneuber-SnominalAmp(idat-1) )/xslope
     &          +StressAmp(idat-1)
C        Stress= 10.0**Clog
        Stress=C
        xslope=
     &     (SnominalAmp(idat) -SnominalAmp(idat-1))
     &    /(StrainAmp(idat)-StrainAmp(idat-1) )
        C=  (Sneuber-SnominalAmp(idat-1) )/xslope
     &          +StrainAmp(idat-1)
C        Strain= 10.0**Clog
         Strain=C
         if(debugMat)then
           write(0,95)SnominalAmp(idat-1),Sneuber,SnominalAmp(idat)
           write(6,95)SnominalAmp(idat-1),Sneuber,SnominalAmp(idat)
   95      format("#matfile #Snominal: ",3(f8.2,1x))

           write(0,96)StressAmp(idat-1),Stress,StressAmp(idat)
           write(6,96)StressAmp(idat-1),Stress,StressAmp(idat)
   96      format("#matfile #Stress  : ",3(f8.2,1x))

           write(0,97)StrainAmp(idat-1),Strain,StrainAmp(idat)
           write(6,97)StrainAmp(idat-1),Strain,StrainAmp(idat)
   97      format("#matfile #Strain  : ",3(f8.5,1x))
         endif

        return
        end



C============================================================================
      SUBROUTINE getloop(Stress,Straintemp,Stresstemp,npts,iexit)
      SAVE
C     Given Stress Ampl., get all stress-strain points from 0 to Stress
C---------------------------------------------------------------------------
C Subroutine from GNU GPL software: fde.uwaterloo.ca/Fde/Calcs/saefcalc1.html

C  Copyright (C) 2000 SAE Fatigue Design and Evaluation Committee
C  This program is free software; you can redistribute it and/or
C  modify it under the terms of the GNU General Public License as
C  published by the Free Software Foundation; either version 2 of the
C  license, or (at your option) any later version.
C
C  This program is distributed in the hope tha it will be useful,
C  but WITHOUT ANY WARRANTY; without even the implied warranty of
C  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
C  GNU General PUblic License for more details.
C
C  You should have received a copy of the GNU General PUblic License
C  along with this program; if not, write to the Free Software
C  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
C  Try also their web site: http://www.gnu.org/copyleft/gpl.html
C---------------------------------------------------------------------------
      real Stresstemp(250),Straintemp(250)

C  From saefcalc1.f:
C      real StressAmp(250), StrainAmp(250), SelasticAmp(250),
C     &     Lifecycles(250), PlstrainAmp(250), ElstrainAmp(250),
C     &     SigmaxStrainAmp(250)
C      integer ndata
C      real FractureStress,FractureStrain
C      Common/Material/ StressAmp,StrainAmp,SelasticAmp,Lifecycles,
C     &                 PlstrainAmp,ElstrainAmp,SigmaxStrainAmp,
C     &                 ndata,FractureStress,FractureStrain

C     Storage for the equal spaced Snom.interval fitted data table in "matfile".
      real StressAmp(1500), StrainAmp(1500), SnominalAmp(1500)
      integer*4 nmatdata,maxmatdata
C      real FractureStress,FractureStrain,Emod
      logical debugMat
      common/MATERIAL/ StressAmp,StrainAmp,SnominalAmp,
     &      snominalInterval,nmatdata,maxmatdata,debugMat

      iexit=0

      Stresstemp(1)=0.
      Straintemp(1)=0
      npts=1

C       We are assuming that the data has been sorted to largest life,
C       and thus smallest stress, strain etc, first.
C       If the stress is below the first stress point, then it is below
C       the fatigue limit (the first life value in the table).

      if(Stress .lt. StressAmp(1))then
C       Yes, its below. Assume straight line from (0,0)
        npts=npts+1
        Straintemp(npts)=(Stress/StressAmp(1))*StrainAmp(1)
        Stresstemp(npts)=Stress
        go to 9000
      endif
      
C     Check if data is above max available
      if(Stress .ge. StressAmp(nmatdata))then
C       The specimen probably fails in first 1/2 cycle. Damage is >= 1.
        do 50 i=1,ndata
          npts=npts+1
          Straintemp(npts)=StrainAmp(i)
          Stresstemp(npts)=StressAmp(i)
   50   continue
        npts=npts+1
        Straintemp(npts)=StrainAmp(nmatdata)
        Stresstemp(npts)=StressAmp(nmatdata)
        iexit=1
        go to 9000
      endif

C     Ok, the input appears to lie between the two extremes. Lets
C     hunt & peck.  Basically we are going to hunt our way up the stress
C     ladder.  When our point is bigger than the last rung, and smaller than
C     the next rung, we can interpolate.

      do 1000 idat=1,ndata
        if(Stress - StressAmp(idat) ) 100,200,300
C         In-elegant but fast:          -ve  0  +ve
C         When the result is -ve, then the curve point is just above
C         the point we want, and we can interpolate.


  100   continue
C       The stress is less than the point on the curve, we have arrived
C       Interpolate.  Try log-log interpl.  If we ever get -ve stresses
C       or strains we will definitely have to go to linear interpl.
        xslope=
     &     (ALOG10(StressAmp(idat)) -ALOG10(StressAmp(idat-1)))
     &    /(ALOG10(StrainAmp(idat))-ALOG10(StrainAmp(idat-1)) )
        Clog=  (ALOG10(Stress)-ALOG10(StressAmp(idat-1)) )/xslope
     &          +ALOG10(StrainAmp(idat-1))
        npts=npts+1
        Straintemp(npts)= 10.0**Clog

        deltS=StressAmp(idat)-StressAmp(idat-1) 
        fraction=(Stress-StressAmp(idat-1))/deltS
        Stresstemp(npts)=StressAmp(idat-1) + fraction*deltS
        go to 9000

  200   continue
C       The stress is exactly equal to the curve point(idat)
C       There could be a "flat" spot in the stress-strain curve, and
C       thus the next point would have the same stress value. Check
Cbugfix   May2005 : im was not incrementing. fixed:
        im=idat
  201   im=im+1
        if(Stress .eq. StressAmp(im))then
C         yes, another is equal. is there more?
          go to 201
        endif
C       No, now the (im) point has bigger stress, use the last
C       one that was equal as a match
Cbugfix   May2005 : Should be im-1
        npts=npts+1
        Straintemp(npts)=StrainAmp(im-1)
        Stresstemp(npts)=Stress
        go to 9000

  300   continue
C       Ok, Point(idat) on the curve is still smaller, keep going
        npts=npts+1
        Straintemp(npts)=StrainAmp(idat)
        Stresstemp(npts)=StressAmp(idat)

C      end of hunting loop
 1000  continue

        write(0,*)" ERROR:plateWeldflaw:getloop.endofdoloop"
        iexit=1
C       We should not be here.  Assume fracture strain
        npts=npts+1
        Straintemp(npts)=StrainAmp(nmatdata)
        Stresstemp(npts)=StressAmp(nmatdata)
        go to 9000

 9000   continue
        write(6,*)"#debug Plot loop for Stress Amp: ",Stress
        write(6,*)"   Amplitudes        Ampl.*2"
        do 9005 i=1,npts
        write(6,9003)Straintemp(i),Stresstemp(i),
     &   Straintemp(i)*2.0,Stresstemp(i)*2.0
 9003   format(2(1x,f7.5,1x,f6.1))
 9005   continue
        end




C======================================================================
      SUBROUTINE getPeakLoads(ivec,iret)
      SAVE
C     ivec= function instruction, usually=1            Last change Oct2013
C     iret= return value 
C     s/r to look at the total stress and remove any non-reversal points
C     from the load history.   Each load set has an integer flag to
C     designate loads to be removed from the memory.  In this program we are
C     focused on the total stress  ststot() to decide removal or keep.

c     Load history storage.  If changing dimensions, also change same 
C                             in mainline
C     Stress membrane, bending, and total storage:
      real*4 stsm(5000),stsb(5000),ststot(5000)
      integer*4 iloadflag(5000) ! 1=save 2=delete  n=repeat
      real*4 ststotmax,ststotmin,ststotwindow
      integer*4 nloads
      logical debugLoads
      common /LOADS/ stsm,stsb,ststot,iloadflag, ststotmax,ststotmin,
     &               ststotwindow,nloads,debugLoads

      real*4 stsold ! the last reversal point
      real*4 stshere ! the present position
      real*4 stsnext ! the next point being examined

      ngood=0                 ! records the no. of good points
      n=0                     ! points to the data being examined
      nbad=0                  ! counts the no. of points being eliminated

C     Get the first point.
      n=n+1
      stsold=ststot(1)
      nstsold=1
      ngood=ngood+1

C     check if the first and last point in the history are same
C     Do this after filtering
      if(ststot(1).eq.ststot(nloads) )then
        write(0,90)
        write(6,90)
   90   format("#history #First and last pts in history are same."/
     &         "#history #Eliminating the 1st history point now")
        nbad=nbad+1
        iloadflag(1)=0
C       Save a copy for rainflow file created near end of program
        ststot1=ststot(1) ! Not used. Adds an extra ramp per block!
      endif

C     Get the second point   stspres  to create the initial line.
  100 continue
      n=n+1
      stsnext=ststot(n)    !get the 2nd point
      nstspres=n

      if(stsnext .eq. stsold)then ! remove the new point
        nbad=nbad+1
        iloadflag(nstspres)=0
        write(6,*)"#DeleteLd samePoint: ",nstspres,stspres
        go to 100
      endif


C     1st (stsold) and 2nd pts (stspres) have been read in----------------
C     2nd pt is not equal to 1st.  Establish direction
      iupdown=+1
      if(stsnext .lt. stsold)iupdown=-1
C     stspres is acceptable
      if(debugLoads)write(6,*)"#stsold,nstsold,stspres,nstspres",
     &               stsold,nstsold,stspres,nstspres,iupdown

C     ok, first point and direction is set. Keep going
 2000 continue
      n=n+1
      if(n .gt. nloads)go to 9000
      stsnext=ststot(n)
      nstsnext=n
      if(debugLoads)write(6,*)"#stsnext,nstsnext: ",stsnext,nstsnext,
     &             iupdown
C     If its equal to the old one we can eliminate the new point
      if(stsnext .eq. stspres)then
        nbad=nbad+1
        iloadflag(nstsnext)=0
        write(6,*)"#DeleteLd samePoint: ",nstsnext stsnext
        go to 2000
      endif

C     No, its not equal.  Could be a reversal  or a continuation of ramp.

      if(stsnext .lt. stspres)go to 3000  ! Potentially it is a reversal point, downwards
C     If not, then things are going in the same direction  if iupdown =1

C     New is going upwards--------------------------------------------------
C     If the same direction we can discard stspres  
      if(iupdown .eq. +1)then
C        Same direction but further, discard pres pt
      if(debugLoads)write(6,*)"#discarding pres pt no.",
     &                 nstspres," iud= ",iupdown
         nbad=nbad+1
         iloadflag(nstspres)=0
        write(6,*)"#Delete non-revPoint: ",nstspres,stspres
         stspres=stsnext
         nstspres=nstsnext
         go to 2000 ! get next point
       endif

C      iupdown must have been = -1,  thus previous direction was in compression.
C      If we get to this point then it is a potential reversal.
C      See if its size is bigger than the allowable window
       if((stsnext-stspres) .lt. ststotwindow)then  ! too small, skip new pt
         nbad=nbad+1
         iloadflag(nstsnext)=0
        write(6,*)"#Delete tooSmallPoint: ",nstsnext,stsnext
         go to 2000  !go get a new one
       endif

C      Ok, it is bigger than the window. Must be a reversal
       if(debugLoads)write(6,*)"#Rev. C_T: old, pres, next ",
     &        stsold,nstsold,stspres,nstspres,stsnext,nstsnext
       ngood=ngood+1
       iupdown=+1   !change direction
C      Set up the reversal point as old
       stsold=stspres
       nstsold=nstspres
       stspres=stsnext
       nstspres=nstsnext
       go to 2000

C     New is going downwards -------------------------------------------------------
 3000 continue
C     the new point is going downwards.  Check the old direction
      if(iupdown .eq. -1)then  ! same direction
C       Discard the old point, and replace it with the new pt.
         nbad=nbad+1
         iloadflag(nstspres)=0
        write(6,*)"#Delete non-revPoint: ",nstspres,stspres
         stspres=stsnext
         nstspres=nstsnext
         go to 2000
      endif

C     iupdown was +1, previous direction was into tension
C     Potential change in direction.  Is it bigger than the window
      if((stspres-stsnext) .lt. ststotwindow)then
C       too small, eliminate the new point
         nbad=nbad+1
         iloadflag(nstsnext)=0
        write(6,*)"#Delete tooSmallPoint: ",nstsnext,stsnext
         go to 2000
      endif

C     Ok, reversal is bigger than the window. Its a reversal
      ngood=ngood+1
      if(debugLoads)write(6,*)"#Rev.T_C: old, pres, next ",
     &   stsold,nstsold,stspres,nstspres,stsnext,nstsnext
      iupdown=-1
      stsold=stspres
      nstsold=nstspres
      stspres=stsnext
      nstspres=nstsnext
      go to 2000

 9000 continue
      if(nbad.eq.0)then    ! no points eliminated
        write(0,9002)
        write(6,9002)
 9002   format("#history #No points needed to be eliminated."/)
        ngood=nloads
        go to 9400  ! print out the filtered history and rainflow 
      endif

      write(0,9005)ngood,nbad
      write(6,9005)ngood,nbad
 9005 format("#history #PPICK found ",i7,"good pts, and ",i7,
     &       " to be eliminated. See list above.")

C     ------------------selction is done.  Must now eliminate and update list

 9400 continue
C     Now go throught the stress storage and take out those to be eliminated
C     Start at the first point to be eliminated
      iput=0        ! index points to next available (empty) storage point
 9500 continue
      iput=iput+1
      if(iloadflag(iput) .ne. 0)goto 9500
C      write(6,*)"#empty at= ",iput  !debug
C     yes flag is 0,  this spot is open for a good pt.

C     Now find the next pt that needs to be saved
      jnextsavept=iput
 9520 continue
      jnextsavept=jnextsavept+1
      if(jnextsavept .gt. nloads)goto 9600  ! end of data found
      if(iloadflag(jnextsavept) .eq. 0)goto 9520
C      write(6,*)"#nextFull at= ",jnextsavept  !debug

C     Yes, we have the next point with iloadflag=1
C     Move this next point to the available postition at iput
      stsm(iput)=stsm(jnextsavept)
      stsb(iput)=stsb(jnextsavept)
      ststot(iput)=ststot(jnextsavept)
      iloadflag(iput)=iloadflag(jnextsavept)
      iloadflag(jnextsavept)=0   !set the moved pt flag to 0
C     For Pdprop  crack propagation programs:
C      write(6,9530)stsm(iput),stsb(iput),ststot(iput),
C     &     iloadflag(iput),iput
C 9530 format("#history #FilteredOut",3(f7.1,1x),i6,1x,i6)
      goto 9500

 9600 continue
C     End of data encountered.
C     Right now iput is still sitting on a flag=0 pt.
      iput=iput-1  ! point back to last non-zero flag point.

C     End-Begin Alignment Check-----------------------------------
C     Check if the first and last point in the history are same
C     Do this after filtering
      nstart=1  !  This is starting point of history, Change?
      if(ststot(1).eq.ststot(nloads) )then
        nstart=2
        write(0,9604)ststot(1),ststot(nstart)
        write(6,9604)ststot(1),ststot(nstart)
 9604   format("#history #1st and Last pts in Filtered hist are same."/
     &         "#history # ststot(1)= ",f8.2/
     &         "#history #Eliminating the 1st history point now"/
     &         "#history #New start pt: ststot()= ",f8.2)
C       Save a copy for rainflow file created near end of program
        ststot1=ststot(2) ! Not used. Adds an extra ramp per block!
      endif

C     There is still the problem of aligning the begin/end of the
C     filtered history.  The PDlisting process does not like two 
C     points in the same direction, one after the other.
C     The method is to look at the end slope, the joint slope, and
C     the begin slope.  If any of these three have "two in a row"
C     with the same sign, we have an alignment problem.
      iwrap=1   ! =1 means Ok,  =0 means problem
      iendDir= +1
      if( (ststot(iput) - ststot(iput-1)) .lt. 0.)iendDir=-1
      ijoinDir= +1
      if( (ststot(nstart) - ststot(iput)) .lt. 0.)ijoinDir=-1
      ibeginDir=  +1
      if( (ststot(nstart+1) - ststot(nstart)) .lt. 0.)ibeginDir=-1

      write(0,*)"#ststot(nstart): ",ststot(nstart), nstart
      write(0,*)"#ststot(nstart+1): ",ststot(nstart+1), nstart+1
      write(0,*)"#ststot(iput-1): ",ststot(iput-1), iput-1
      write(0,*)"#ststot(iput): ",ststot(iput), iput
      write(0,*)"#iendDir: ",iendDir
      write(0,*)"#ijoinDir: ",ijoinDir
      write(0,*)"#ibeginDir: ",ibeginDir

      if(iendDir .eq. ijoinDir)iwrap=0
      if(ijoinDir .eq. ibeginDir)iwrap=0
      if(iwrap .eq. 0)then
        write(0,9608)ststot(iput-1),ststot(iput),ststot(nstart),
     &               ststot(nstart+1)
        write(6,9608)ststot(iput-1),ststot(iput),ststot(nstart),
     &               ststot(nstart+1)
 9608   format("#history #Warning: After filtering: End of history and",
     &         "Begining have an alignment problem:"/
     &         "#history # Last-1 Pt:  ",f8.2/
     &         "#history # Last   Pt:  ",f8.2/
     &         "#history # 1st    Pt:  ",f8.2/
     &         "#history # 2nd    Pt:  ",f8.2)
        
C       Check if all three same direction
        if((iendDir.eq.ijoinDir).and.(ijointDir.eq.ibeginDir) )then
          write(0,9612)
          write(6,9612)
 9612     format("#history # All in same direction.  Eliminate 1st and",
     &           " last points.")
          nstart=nstart +1 ! get rid of 1st pt.
          iput=iput-1      ! get rid of last pt.
          goto 9620
        endif

        if(iendDir .eq. ijoinDir)then
          write(0,9616)
          write(6,9616)
 9616     format("#history # Last and Join in same direction. ",
     &           "Eliminating the Last point.")
          iput=iput-1
          goto 9620
        endif

        if(ijoinDir .eq. ibeginDir)then
          write(0,9618)
          write(6,9618)
 9618     format("#history # Join and Begin are same direction.",
     &           "Eliminating the First point.")
          nstart=nstart+1
          goto 9620
        endif
      endif
C     Thinking about this some more:  It would probably achieve the
C     same effect by adding the 1st point  onto the end of the pre-filter
C     history and then filtering.   (too late now :)
C     Perhaps it is better to check "properly" as above anyway.

 9620 continue
      write(0,9630)ngood,iput
      write(6,9630)ngood,iput
 9630 format("#history #BugCheck: GoodPtsFound=",i8,
     &      " GoodPtsSaved=",i8," should be nearly equal?.")

C     When nstart is not equal to 1  anymore we need to shift the
C     history such that the start point, presently = nstart,  is pt 1

C     Check results with a full print
      icount=0
      do 9800 i=nstart,iput
        icount=icount+1
        write(6,9790)stsm(i),stsb(i),ststot(i),iloadflag(i),icount
 9790   format("#history #Filteredck ",3(f7.1,1x),i8,1x,i6)
        if(nstart .ne. 1)then
C         Shift the history to compensate for nstart > 1
          stsm(icount)     =stsm(i)
          stsb(icount)     =stsb(i)
          ststot(icount)   =ststot(i)
          iloadflag(icount)=iloadflag(i)
        endif
 9800 continue

C     Also write out a file for rainflow count + StrainStrainLife
      open(unit=10,file="loads4rain.out")
      write(10,9838)ststotmax,ststotmin
 9838 format("#MAX= ",e14.7/"#MIN= ",e14.7/"#BEGIN")
C      write(10,9839)ststot1   ! not a good idea. Distorts history.
C 9839 format(" 0 ",f7.1)
      do 9850 i=nstart,iput
        write(10,9840)i,ststot(i)
 9840   format(i9,1x,f7.1,1x)
 9850 continue
      close(unit=10)

      write(0,9854)icount,icount
      write(6,9854)icount,icount
 9854 format("#NLOADSETS= ",i8," (loads in each history repetition ",
     $       "after filtering"/"#Wrote ststot() out for rainflow. ",
     $       "nloads= ",i8,"  into file: loads4rain.out")

      nloads=icount
      return
      end


C==============================================================

      SUBROUTINE subCutBlanks(idevice,inp1,idimen)
      SAVE
C  subCutBlanks.f   s/r to remove the leading and trailing blanks for output
C     Used mainly to print long comment lines
C  Usage:    call subCutBlanks(idevice,inp400,idimen)
C                              idevice= output device no. in fortran
C                              inp400=  char storage vector
C                              idimen=  length of incoming char string
C                                       (or how many to look at ?)

C  Copyright (C) 2013  Al Conle
C This file is free software; you can redistribute it and/or modify
C it under the terms of the GNU General Public License as published by
C the Free Software Foundation; either version 2 of the license, or (at
C your option) any later version.
C  This  file is distributed in the hope that it will be useful, but
C WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTA-
C BILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
C License for more details.
C  You should have received a copy of the GNU General PUblic License along
C with this program; if not, write to the Free Software Foundation, Inc.,
C 59 Temple Place -Suite 330, Boston, MA 02111-1307, USA. Try also their
C web site: http://www.gnu.org/copyleft/gpl.html

      integer*4  idevice,idim, ncharmax/400/
      integer*4  ifirst,ilast
      character*1 inp1(400)  ! if you change this, change also ncharmax above

C     Check for programming error:
      if(idimen .gt. ncharmax)then
       write(0,100)idimen,ncharmax
  100  format("#Error: s/r subCutBlanks(): dimension of char varible= ",
     & i10," bigger than max allowed =",i5," stopping...")
       stop
      endif
      if(idimen .lt. 1 )then
       write(0,100)idimen
  101  format("#Error: s/r subCutBlanks(): dimension of char varible= ",
     & " is less than 1,  stopping...")
       stop
      endif
         
C     Find the first non-blank character
      do 200 i=1,ncharmax
         if(inp1(i) .eq. " ")goto 200
         ifirst=1
         goto 210
  200 continue
C     if we end up here there are no chars within inp(1) and inp(idimen)
C     Just write out one blank for this line
      write(idevice,205)
  205 format(" ")
      return

  210 continue  !  now hunt for the last char by starting at idimen and 
C                  working backwards.
      do 300 i=idimen,1,-1
         if(inp1(i) .eq. " ")goto 300
         ilast=i  !  No?, then we have found an non blank
         go to 310
  300 continue
C     If we end up here, the whole line was blanks, write out one blank
      write(idevice,205)
      return

  310 continue  ! ifirst and ilast are set, write out the stuff
      write(idevice,315)(inp1(i),i=ifirst,ilast)
  315 format(400a1)
      return
      end



C======================================================================
      SUBROUTINE getMmMb00a90(ivec,iret,aoc,aob,xMm00,xMb00,xMm90,xMb90)
      SAVE
C     ivec= function instruction  =1=interpolate         (input)
C                                 =2 turn on debug
C     iret= return value = 0 if no errors                (return)
C     aoc=  a/c  crack depth / half crack surface length (input)
C     aob=  a/B  crack depth / Plate thickness           (input)
C     xMm00=  multiplication factor for membrane stress  (return)
C     xMb00=  multiplication factor for bending stress   (return)
C     xMm90=  multiplication factor for membrane stress  (return)
C     xMb90=  multiplication factor for bending stress   (return)

C     s/r to interpolate for Mkm and Mkb for: both 00 deg and 90 deg
C      (where 0 deg is along surface of plate, and 90 deg is deepest pt. of crack)
C     As long as the dimensions of the storage matrices are the same we
C     will save some computation time in calculating the location of the solutions
C     in the matrix because aoc and aob  are the same for both 00deg and 90deg.
C     i.e. the four pts in the matrix will have the same j,i  co-ordinates.

C    The input file for 90deg looks like this:      ( 00deg is similar)
C# getMmMb vers. 0.4 starts...
C#ROWS=   51
C#COLS=   11
C#theta=  0.1570796E+01   #radians =  90.00 deg.
C#iaoc iaob a/c a/B         Mm          Mb
C  1  1 0.000  0.00  0.1130000E+01  0.1130000E+01
C  1  2 0.000  0.10  0.1170396E+01  0.1034045E+01
C  1  3 0.000  0.20  0.1307138E+01  0.1016954E+01
C  1  4 0.000  0.30  0.1586888E+01  0.1084638E+01
C  1  5 0.000  0.40  0.2087415E+01  0.1252449E+01
C  1  6 0.000  0.50  0.2917596E+01  0.1539032E+01
C  1  7 0.000  0.60  0.4217416E+01  0.1965316E+01
C  1  8 0.000  0.70  0.6157967E+01  0.2558635E+01
C  1  9 0.000  0.80  0.8941448E+01  0.3361984E+01
C  1 10 0.000  0.90  0.1280117E+02  0.4448406E+01
C  1 11 0.000  1.00  0.1800154E+02  0.5940509E+01
C
C  2  1 0.040  0.00  0.1122352E+01  0.1122352E+01
C  2  2 0.040  0.10  0.1154351E+01  0.1018274E+01
C etc...

C The data was read into common by   readMmMb00.f   and readMmMb90.f


C     Matrices for storing Mm, Mb
      real*4 mb00(51,11),mm00(51,11),mb90(51,11),mm90(51,11)
      integer*4 nmmdatarow,maxmmdatarow, nmmdatacol, maxmmdatacol
C     Limits and intervals of input data used for quicker interpolation
      real*4 startaoc, endaoc, deltaaoc
      real*4 startaob, endaob, deltaaob
      logical debugMm,lactivateMmMb
      common/MMDATA/   mb00,mm00,mb90,mm90,
     &       nmmdatarow,maxmmdatarow, nmmdatacol, maxmmdatacol,
     &      startaoc,endaoc,deltaaoc, startaob,endaob,deltaaob,debugMm,
     &      lactivateMmMb

      logical debug
      debug= .false.
      if(ivec.eq.2)debug= .true.   !set to true if testing code
      if(debugMm)debug= .true.

C---------------------Interpolate ------------------
C
C     Use 2D interpolation: http://en.wikipedia.org/wiki/Bilinear_interpolation
C     Given the aoc and aob inputs, we need to establish the four known
C     matrix points that surround this  x,y pair.   It may also be that we
C     are directly on one of the four points.

C     The matrix row and cols are equal sized increments.  Thus we can "jump"
C     to the relative co-ords without  step wise searching.

C      real*4 startaoc, endaoc, deltaaoc
C      real*4 startaob, endaob, deltaaob
      i=ifix((aoc-startaoc)/deltaaoc)+1
      j=ifix((aob-startaob)/deltaaob)+1
      if(i.lt.1 .or. j.lt.1 .or. j.gt.maxmmdatacol .or.
     &   i.gt. maxmmdatarow) then
C        Out of bounds error
         write(0,1010)startaoc,aoc,endaoc,
     &                startaob,aob,endaob,i,j
 1010    format("#ERROR: S/R getMmMb00a90 a/c or a/b out of bounds:"/
     &    "#      start a/c=",f6.3," a/c= ",e14.7," end a/c= ",f6.3/
     &    "#      start a/b=",f6.3," a/b= ",e14.7," end a/b= ",f6.3/
     &    "#      i,j=  ",i5,1x,i5/
     &    "# Stopping...")
          iret=1010    ! set the error flag to format sta. no.
          return
      endif

C     j,i  is the corner (see internet address above)  of x1,y1
      ip1=i+1
      jp1=j+1
C     We need to use x1, x2, y1, y2 to calculate Mm and Mb
C     x,y  are aob,aoc
      x=aob
      y=aoc

C     Things appear to be within bounds of matrices, continue
      x1=startaob+float(j-1)*deltaaob
      x2=x1+deltaaob
      y1=startaoc + float(i-1)*deltaaoc
      y2=y1+deltaaoc
      if(debug)then
        write(0,1015)x1,y1,  x2,y1, x,y, x1,y2, x2,y2
        write(6,1015)x1,y1,  x2,y1, x,y, x1,y2, x2,y2
 1015   format("#TargetCo-ords:"/
     &        "#x1,y1       x2,y1  :",2f7.4,14x,2f7.4/
     &        "#       x,y         :",15x,2f7.4/
     &        "#x1,y2       x2,y2  :",2f7.4,14x,2f7.4/
     &  )
        write(0,1016)i,j,  i,jp1,  ip1,j, ip1,jp1
        write(6,1016)i,j,  i,jp1,  ip1,j, ip1,jp1
 1016   format("# i,j       i,j+1    : "i3,",",i3, 10x, i3,",",i3/
     &         "# i+1,j     i+1,j+1  : "i3,",",i3, 10x, i3,",",i3/
     &  )
      endif

      Q11=mm90(i,j)
      Q12=mm90(ip1,j)
      Q21=mm90(i,jp1)
      Q22=mm90(ip1,jp1)

C     Ok, lets find  R1 on the line between q11 and q21
C     Original formula is:
C      R1= ( (x2-x)/(x2-x1))*Q11 + ((x-x1)/(x2-x1))*Q21
C      R2= ( (x2-x)/(x2-x1))*Q12 + ((x-x1)/(x2-x1))*Q22
C     Since we use same for Mm and Mb compute once
      x2mx=x2-x
      x2mx1 = x2-x1
      xmx1= x-x1
      frac1= x2mx/x2mx1
      frac2= xmx1/x2mx1
      
C      R1=(x2mx/x2mx1)*Q11 + (xmx1/x2mx1)*Q21
C      R2=(x2mx/x2mx1)*Q12 + (xmx1/x2mx1)*Q22
      R1 = frac1*Q11 + frac2*Q21
      R2 = frac1*Q12 + frac2*Q22
      
      y2my1=y2-y1
      frac1y= (y2-y)/y2my1 
      frac2y= (y-y1)/y2my1
C      xmm = ( (y2-y)/y2my1 )*R1 + ( (y-y1)/y2my1 )*R2
      xMm90 = frac1y*R1 + frac2y*R2
      if(debug)then
        write(0,1020)aoc,aob,i,j, Q11,R1,Q21, xMm90, Q12,R2,Q22
        write(6,1020)aoc,aob,i,j, Q11,R1,Q21, xMm90, Q12,R2,Q22
 1020   format("#Solution for a/c= ",f6.3," a/b= ",f6.3," (i,j)=",2i3/
     &        "# Q11,  R1,  Q21 :  ",3(f7.4,1x)/
     &        "#      Mm90=     :  ",10x,f7.4/
     &        "# Q12,  R2,  Q22 :  ",3(f7.4,1x)/
     &        )
      endif

C     Now do the  Mb  interp.
      Q11=mb90(i,j)
      Q12=mb90(ip1,j)
      Q21=mb90(i,jp1)
      Q22=mb90(ip1,jp1)

      R1 = frac1*Q11 + frac2*Q21
      R2 = frac1*Q12 + frac2*Q22
      xMb90 = frac1y*R1 + frac2y*R2
      if(debug)then
        write(0,1022)aoc,aob,i,j, Q11,R1,Q21, xMb90, Q12,R2,Q22
        write(6,1022)aoc,aob,i,j, Q11,R1,Q21, xMb90, Q12,R2,Q22
 1022   format("#Solution for a/c= ",f6.3," a/b= ",f6.3," (i,j)=",2i3/
     &        "# Q11,  R1,  Q21 :  ",3(f7.4,1x)/
     &        "#      Mb90=     :  ",10x,f7.4/
     &        "# Q12,  R2,  Q22 :  ",3(f7.4,1x)/
     &        )
      endif

C----------Now do the  Mb00  and Mm00   interpolations
C          Note!!! this only works if the matrices have same dimensions !!
C                  and same aoc and aob  for each entry !!
      Q11=mm00(i,j)
      Q12=mm00(ip1,j)
      Q21=mm00(i,jp1)
      Q22=mm00(ip1,jp1)

      R1 = frac1*Q11 + frac2*Q21
      R2 = frac1*Q12 + frac2*Q22
      
      xMm00 = frac1y*R1 + frac2y*R2
      if(debug)then
        write(0,1024)aoc,aob,i,j, Q11,R1,Q21, xMm00, Q12,R2,Q22
        write(6,1024)aoc,aob,i,j, Q11,R1,Q21, xMm00, Q12,R2,Q22
 1024   format("#Solution for a/c= ",f6.3," a/b= ",f6.3," (i,j)=",2i3/
     &        "# Q11,  R1,  Q21 :  ",3(f7.4,1x)/
     &        "#      Mm00=     :  ",10x,f7.4/
     &        "# Q12,  R2,  Q22 :  ",3(f7.4,1x)/
     &        )
      endif

C     Now do the  Mb  interp.
      Q11=mb00(i,j)
      Q12=mb00(ip1,j)
      Q21=mb00(i,jp1)
      Q22=mb00(ip1,jp1)

      R1 = frac1*Q11 + frac2*Q21
      R2 = frac1*Q12 + frac2*Q22
      xMb00 = frac1y*R1 + frac2y*R2
      if(debug)then
        write(0,1026)aoc,aob,i,j, Q11,R1,Q21, xMb00, Q12,R2,Q22
        write(6,1026)aoc,aob,i,j, Q11,R1,Q21, xMb00, Q12,R2,Q22
 1026   format("#Solution for a/c= ",f6.3," a/b= ",f6.3," (i,j)=",2i3/
     &        "# Q11,  R1,  Q21 :  ",3(f7.4,1x)/
     &        "#      Mb00=     :  ",10x,f7.4/
     &        "# Q12,  R2,  Q22 :  ",3(f7.4,1x)/
     &        )
      endif



      iret=0
      return
      end

C==============================================================================
      SUBROUTINE getMkmMkb00a90(ivec,iret,aoc,aob,
     &              xMkm00,xMkb00,xMkm90,xMkb90)
      SAVE
C     ivec= function instruction  =1=interpolate         (input)
C                                 =2 turn on debug
C     iret= return value = 0 if no errors                (return)
C     aoc=  a/c  crack depth / half crack surface length (input)
C     aob=  a/B  crack depth / Plate thickness           (input)
C     xMkm00=  multiplication factor for membrane stress  (return)
C     xMkb00=  multiplication factor for bending stress   (return)
C     xMkm90=  multiplication factor for membrane stress  (return)
C     xMkb90=  multiplication factor for bending stress   (return)

C     s/r to interpolate for Mkm and Mkb for: both 00 deg and 90 deg
C      (where 0 deg is along surface of plate, and 90 deg is deepest pt. of crack)
C     As long as the dimensions of the storage matrices are the same we
C     will save some computation time in calculating the location of the solutions
C     in the matrix because aoc and aob  are the same for both 00deg and 90deg.
C     i.e. the four pts in the matrix will have the same j,i  co-ordinates.

C    The input file for 90deg looks like this:      ( 00deg is similar)
C   For the file format see the Fortran programs getMk_w00.f  getMk_w90.f
C   or see some of the example files such as "t_MkmMkb_w00_LoB=1.0"
C   In those programs the data is written out with the sta.:
C         write(6,400)iaoc,iaob,aoc,aob,LoB,xMkm,xMkb,  fm1,fm2,fm3,f1,f2,f3
C   For us, only the first 7 elements need to be read from each line.
C   Example begining of a file:
C   # getMk_w00 vers. 0.1 starts...
C   #ROWS=  200
C   #COLS=   18
C   #LoB=  1.000
C   #iaoc iaob a/c a/B    L/B    Mkm    Mkb
C     1   1 0.100  0.005  1.00  6.346  6.135  4.707  1.551  0.869  4.758  1.548  0.833
C     1   2 0.100  0.010  1.00  5.247  5.230  3.913  1.535  0.874  4.037  1.555  0.833
C     1   3 0.100  0.015  1.00  4.656  4.709  3.504  1.518  0.876  3.647  1.551  0.832
C     1   4 0.100  0.020  1.00  4.268  4.349  3.236  1.505  0.876  3.386  1.546  0.831
C etc...

C   For a given L/B ratio all the data will be stored in 4 matrices, each 
C   sized in 200x18  (Rows x Columns)

C The data was read into common by   readMkmMkb00.f   and readMkmMkb90.f

      integer*4 ivec,iret
      real*4 xMkm00,xMkb00, xMkm90,xMkb90

C     Matrices for storing Mkm, Mkb
      real*4 mkb00(18,200),mkm00(18,200),mkb90(18,200),mkm90(18,200)
      integer*4 nmkdatarow,maxmkdatarow, nmkdatacol, maxmkdatacol
C     Limits and intervals of input data used for quicker interpolation
      real*4 startaoc2, endaoc2, deltaaoc2
      real*4 startaob2, endaob2, deltaaob2
      logical debugMk,lactivateMkmMkb
      common/MKDATA/  mkb00,mkm00,mkb90,mkm90,
     &      nmkdatarow,maxmkdatarow, nmkdatacol, maxmkdatacol,
     &      startaoc2,endaoc2,deltaaoc2, startaob2,endaob2,deltaaob2,
     &      debugMk,lactivateMkmMkb


      logical debug
      debug= .false.
      if(ivec.eq.2)debug= .true.   !set to true if testing code
      if(debugMk)debug= .true.

C     Check on BS standard limits for aob and aoc
      

C---------------------Interpolate ------------------
C
C     Use 2D interpolation: http://en.wikipedia.org/wiki/Bilinear_interpolation
C     Given the aoc and aob inputs, we need to establish the four known
C     matrix points that surround this  x,y pair.   It may also be that we
C     are directly on one of the four points.

C     The matrix row and cols are equal sized increments.  Thus we can "jump"
C     to the relative co-ords without  step wise searching.

C      real*4 startaoc, endaoc, deltaaoc
C      real*4 startaob, endaob, deltaaob
      i=ifix((aoc-startaoc2)/deltaaoc2)+1   ! assumed y axis index
      j=ifix((aob-startaob2)/deltaaob2)+1   ! assumed x axis index
      if(i.lt.1 .or. j.lt.1 .or. j.gt.maxmkdatacol .or.
     &   i.gt. maxmkdatarow) then
C        Out of bounds error
         write(0,1010)startaoc2,aoc,endaoc2,
     &                startaob2,aob,endaob2
         write(6,1010)startaoc2,aoc,endaoc2,
     &                startaob2,aob,endaob2
 1010    format("#ERROR: S/R getMkmMkb00a90 a/c or a/b out of bounds:"/
     &    "#      start_a/c=",f6.3," a/c= ",e14.7," end_a/c= ",f6.3/
     &    "#      start_a/b=",f6.3," a/b= ",e14.7," end_a/b= ",f6.3)
         if(aoc .lt. startaoc2)then
           write(0,1012)
           write(6,1012)
 1012      format("# Probably c has gotten too big... Stopping...")
         endif
         iret=1010    ! set the error flag to format sta. no.
         return
      endif

C     j,i  is the corner (see internet address above)  of x1,y1
      ip1=i+1
      jp1=j+1
C     We need to use x1, x2, y1, y2 to calculate Mm and Mb
C     x,y  are aob,aoc
      x=aob
      y=aoc

C     Things appear to be within bounds of matrices, continue
      x1=startaob2+float(j-1)*deltaaob2
      x2=x1+deltaaob2
      y1=startaoc2 + float(i-1)*deltaaoc2
      y2=y1+deltaaoc2
      if(debug)then
        write(0,1015)x1,y1,  x2,y1, x,y, x1,y2, x2,y2
        write(6,1015)x1,y1,  x2,y1, x,y, x1,y2, x2,y2
 1015   format("#TargetCo-ords:"/
     &        "#x1,y1       x2,y1  :",2f7.4,14x,2f7.4/
     &        "#       x,y         :",15x,2f7.4/
     &        "#x1,y2       x2,y2  :",2f7.4,14x,2f7.4/
     &  )
        write(0,1016)i,j,  i,jp1,  ip1,j, ip1,jp1
        write(6,1016)i,j,  i,jp1,  ip1,j, ip1,jp1
 1016   format("# i,j       i,j+1    : "i3,",",i3, 10x, i3,",",i3/
     &         "# i+1,j     i+1,j+1  : "i3,",",i3, 10x, i3,",",i3/
     &  )
C        write(0,1016)j,i,  jp1,i,  j,ip1, jp1,ip1
C        write(6,1016)j,i,  jp1,i,  j,ip1, jp1,ip1
C 1016   format("# j,i       j+1,i    : "i3,",",i3, 10x, i3,",",i3/
C     &         "# j,i+1     j+1,i+1  : "i3,",",i3, 10x, i3,",",i3/
C     &  )
      endif
      Q11=mkm90(i,j)
      Q12=mkm90(ip1,j)
      Q21=mkm90(i,jp1)
      Q22=mkm90(ip1,jp1)

C      Q11=mkm90(j,i)
C      Q12=mkm90(j,ip1)
C      Q21=mkm90(jp1,i)
C      Q22=mkm90(jp1,ip1)

C     Ok, lets find  R1 on the line between q11 and q21
C     Original formula is:
C      R1= ( (x2-x)/(x2-x1))*Q11 + ((x-x1)/(x2-x1))*Q21
C      R2= ( (x2-x)/(x2-x1))*Q12 + ((x-x1)/(x2-x1))*Q22
C     Since we use same for Mm and Mb compute once
      x2mx=x2-x
      x2mx1 = x2-x1
      xmx1= x-x1
      frac1= x2mx/x2mx1
      frac2= xmx1/x2mx1
      
C      R1=(x2mx/x2mx1)*Q11 + (xmx1/x2mx1)*Q21
C      R2=(x2mx/x2mx1)*Q12 + (xmx1/x2mx1)*Q22
      R1 = frac1*Q11 + frac2*Q21
      R2 = frac1*Q12 + frac2*Q22
      
      y2my1=y2-y1
      frac1y= (y2-y)/y2my1 
      frac2y= (y-y1)/y2my1
C      xmm = ( (y2-y)/y2my1 )*R1 + ( (y-y1)/y2my1 )*R2
      xMkm90 = frac1y*R1 + frac2y*R2
      if(debug)then
        write(0,1020)aoc,aob,i,j, Q11,R1,Q21, xMkm90, Q12,R2,Q22
        write(6,1020)aoc,aob,i,j, Q11,R1,Q21, xMkm90, Q12,R2,Q22
 1020   format("#Solution for a/c= ",f6.3," a/B= ",f6.3," (i,j)=",2i3/
     &        "# Q11,  R1,  Q21 :  ",3(f7.4,1x)/
     &        "#      Mkm90=    :  ",10x,f7.4/
     &        "# Q12,  R2,  Q22 :  ",3(f7.4,1x)/
     &        )
      endif

C     Now do the  Mb  interp.
      Q11=mkb90(i,j)
      Q12=mkb90(ip1,j)
      Q21=mkb90(i,jp1)
      Q22=mkb90(ip1,jp1)

      R1 = frac1*Q11 + frac2*Q21
      R2 = frac1*Q12 + frac2*Q22
      xMkb90 = frac1y*R1 + frac2y*R2
      if(debug)then
        write(0,1022)aoc,aob,i,j, Q11,R1,Q21, xMkb90, Q12,R2,Q22
        write(6,1022)aoc,aob,i,j, Q11,R1,Q21, xMkb90, Q12,R2,Q22
 1022   format("#Solution for a/c= ",f6.3," a/B= ",f6.3," (i,j)=",2i3/
     &        "# Q11,  R1,  Q21 :  ",3(f7.4,1x)/
     &        "#      Mkb90=    :  ",10x,f7.4/
     &        "# Q12,  R2,  Q22 :  ",3(f7.4,1x)/
     &        )
      endif

C----------Now do the  Mkb00  and Mkm00   interpolations
C          Note!!! this only works if the matrices have same dimensions !!
      Q11=mkm00(i,j)
      Q12=mkm00(ip1,j)
      Q21=mkm00(i,jp1)
      Q22=mkm00(ip1,jp1)

      R1 = frac1*Q11 + frac2*Q21
      R2 = frac1*Q12 + frac2*Q22
      
      xMkm00 = frac1y*R1 + frac2y*R2
      if(debug)then
        write(0,1024)aoc,aob,i,j, Q11,R1,Q21, xMkm00, Q12,R2,Q22
        write(6,1024)aoc,aob,i,j, Q11,R1,Q21, xMkm00, Q12,R2,Q22
 1024   format("#Solution for a/c= ",f6.3," a/B= ",f6.3," (i,j)=",2i3/
     &        "# Q11,  R1,  Q21 :  ",3(f7.4,1x)/
     &        "#      Mkm00=     :  ",10x,f7.4/
     &        "# Q12,  R2,  Q22 :  ",3(f7.4,1x)/
     &        )
      endif

C     Now do the  Mb  interp.
      Q11=mkb00(i,j)
      Q12=mkb00(ip1,j)
      Q21=mkb00(i,jp1)
      Q22=mkb00(ip1,jp1)

      R1 = frac1*Q11 + frac2*Q21
      R2 = frac1*Q12 + frac2*Q22
      xMkb00 = frac1y*R1 + frac2y*R2
      if(debug)then
        write(0,1026)aoc,aob,i,j, Q11,R1,Q12, xMkb00, Q21,R2,Q22
        write(6,1026)aoc,aob,i,j, Q11,R1,Q12, xMkb00, Q21,R2,Q22
 1026   format("#Solution for a/c= ",f6.3," a/B= ",f6.3," (i,j)=",2i3/
     &        "# Q11,  R1,  Q12 :  ",3(f7.4,1x)/
     &        "#      Mkb00=     :  ",10x,f7.4/
     &        "# Q21,  R2,  Q22 :  ",3(f7.4,1x)/
     &        )
      endif



      iret=0
      return
      end

C===========================================================================
      SUBROUTINE readMmMb00(ivec,iret)
      SAVE
C     ivec= function instruction =0=read in,  =2=debug
C     iret= return value = 0 if no errors
C     aoc=  a/c  in mm. of crack depth / half crack surface length (input)
C     aob=  a/B  in mm. of crack depth / Plate thickness (input)
C     xMm=  multiplication factor for membrane stress (return)
C     xMb=  multiplication factor for bending stress (return)

C     s/r to read in the Mkm and Mkb for:
C------00 deg   00 deg   00 deg   00 deg   00 deg   00 deg   00 deg   00 deg   00 deg
C      (where 00 deg is along surface of plate, and 90 deg is deepest pt. of crack)

C    The input file (t_MmMb_Surflaw_00) looks like this:
C# getMmMb vers. 0.4 starts...
C#ROWS=   51
C#COLS=   11
C#theta=  0.0000000E+00   #radians =   0.00 deg.
C#iaoc iaob a/c a/B         Mm          Mb
C  1  1 0.000  0.00  0.0000000E+00  0.0000000E+00
C  1  2 0.000  0.10  0.0000000E+00  0.0000000E+00
C  1  3 0.000  0.20  0.0000000E+00  0.0000000E+00
C  1  4 0.000  0.30  0.0000000E+00  0.0000000E+00
C  1  5 0.000  0.40  0.0000000E+00  0.0000000E+00
C  1  6 0.000  0.50  0.0000000E+00  0.0000000E+00
C  1  7 0.000  0.60  0.0000000E+00  0.0000000E+00
C  1  8 0.000  0.70  0.0000000E+00  0.0000000E+00
C  1  9 0.000  0.80  0.0000000E+00  0.0000000E+00
C  1 10 0.000  0.90  0.0000000E+00  0.0000000E+00
C  1 11 0.000  1.00  0.0000000E+00  0.0000000E+00
C
C  2  1 0.040  0.00  0.2469174E+00  0.2469174E+00
C  2  2 0.040  0.10  0.2547652E+00  0.2459911E+00
C  2  3 0.040  0.20  0.2797244E+00  0.2604570E+00
C  2  4 0.040  0.30  0.3261514E+00  0.2924534E+00
C  2  5 0.040  0.40  0.4016670E+00  0.3463333E+00
C  2  6 0.040  0.50  0.5176973E+00  0.4285498E+00
C  2  7 0.040  0.60  0.6902308E+00  0.5476015E+00
C  2  8 0.040  0.70  0.9407914E+00  0.7139853E+00
C  2  9 0.040  0.80  0.1297628E+01  0.9401052E+00
C  2 10 0.040  0.90  0.1797119E+01  0.1240084E+01
C  2 11 0.040  1.00  0.2485397E+01  0.1629426E+01
C
C  3  1 0.080  0.00  0.3454381E+00  0.3454381E+00
C etc...

      character*300  inp300,jnp300,Cwebpage
      character*1    inpone(300),jnpone(300)
      character*10   inpten(30)
      equivalence (inpone(1), inpten(1), inp300)
      equivalence (jnpone(1),jnp300)

C     Matrices for storing Mm, Mb
      real*4 mb00(51,11),mm00(51,11),mb90(51,11),mm90(51,11)
      integer*4 nmmdatarow,maxmmdatarow, nmmdatacol, maxmmdatacol
C     Limits and intervals of input data used for quicker interpolation
      real*4 startaoc, endaoc, deltaaoc
      real*4 startaob, endaob, deltaaob
      logical debugMm,lactivateMmMb
      common/MMDATA/   mb00,mm00,mb90,mm90,
     &       nmmdatarow,maxmmdatarow, nmmdatacol, maxmmdatacol,
     &      startaoc,endaoc,deltaaoc, startaob,endaob,deltaaob,debugMm,
     &      lactivateMmMb


      ndatalines=0
      ninput=0


C------------------------ Read Input file --------------------------------
C     The matrix max limit values have been set at begin of mainline
      write(0,402)
      write(6,402)
  402 format("# Opening Mm_Mb_00deg. table, file= t_MmMb_Surflaw_00")
      open(unit=10,file= "t_MmMb_Surflaw_00",status="old")

  400 continue     !Loop back to here for next input line.
      read(10,"(a300)",end=450)inp300
      ninput=ninput+1

      if(inp300.eq." ")then    ! Check for blank line
C        write(6,"(a1)")" "
        go to 400
      endif

      if(inpone(1).ne."#")then
C        We may have a data line, or someone screwed up and put the # later in line.
C        See if 1st char is a # later in line
         do 405 i=1,300
           if(inpone(i).eq." ") go to 405
C           No? 1st non-blank found, if # its not a data line
            loc=i
           if(inpone(i).eq."#") then
C            Shift the whole mess over to begining of field
             inew=0
             do 403 j=loc,300
              inew=inew+1
              inpone(inew)=inpone(j)
  403        continue
Cdebug        write(0,*)"Shifted a comment: ",(inpone(j),j=1,inew)
C            Ok, now its a nice comment. Go play with it.
             go to 430
           else
C            The first non blank is not a #
              go to 410
           endif
  405      continue
           go to 400  !assume garbage in line.

  410      continue
C        1st non blank is not a #  Check if its a number.
         if(inpone(loc).ne."+" .and.
     &      inpone(loc).ne."-" .and.
     &      inpone(loc).ne."." .and.
     &      inpone(loc).ne."0" .and.
     &      inpone(loc).ne."1" .and.
     &      inpone(loc).ne."2" .and.
     &      inpone(loc).ne."3" .and.
     &      inpone(loc).ne."4" .and.
     &      inpone(loc).ne."5" .and.
     &      inpone(loc).ne."6" .and.
     &      inpone(loc).ne."7" .and.
     &      inpone(loc).ne."8" .and.
     &      inpone(loc).ne."9"  )then
C           It must be a letter, not a number. Time to bomb out.
            write(0,415)ninput
            write(6,415)ninput
  415       format(" ERROR MmMbfile00: input line no. ",I5," 1st Char.",
     &      " not a # and not a number. Fix data in file MmMbfile00")
            stop
         endif
C      real*4 mb00(51,11),mm00(51,11),mb90(51,11),mm90(51,11)
C      integer*4 nmmdatarow,maxmmdatarow, nmmdatacol, maxmmdatacol
C        Ok, its a number
         read(inp300,*) iaoc,iaob,aoc,aob, xm,xb
         ndatalines=ndatalines+1
         if(iaoc .gt. maxmmdatarow .or. iaob .gt. maxmmdatacol)then
           write(0,416)iaoc,iaob
           write(6,416)iaoc,iaob
  416      format(" Error: MmMbfile00: too many data points:",
     &            "rows: iaoc= ",i5," cols: iaob= "i5/
     &            " recompile plateWeldflaw.f or reduce file data")
           stop
         endif
C        Data is within size of matrix. Place into matrices
         mm00(iaoc,iaob)= xm
         mb00(iaoc,iaob)= xb
         write(6,420)iaoc,iaob,aoc,aob,xm,xb
  420    format("#MmMbfile00 ",i4,i4,2(1x,f6.3),2(1x,e14.7))
         if(iaoc.eq.1 .and. iaob.eq.1)then
            startaoc=aoc
            startaob=aob
            write(0,424)startaoc,startaob
            write(6,424)startaoc,startaob
  424       format("#MmMbfile00 #STARTAOC= ",e14.7/
     &             "#MmMbfile00 #STARTAOB= ",e14.7)
         endif
         if(iaoc.eq.maxmmdatarow .and. iaob .eq. maxmmdatacol)then
            endaoc=aoc
            endaob=aob
            write(0,425)endaoc,endaob
            write(6,425)endaoc,endaob
  425       format("#MmMbfile00 #ENDAOC= ",e14.7/
     &             "#MmMbfile00 #ENDAOB= ",e14.7)
         endif
         go to 400
      endif


  430    continue
C        All comment lines are just written out, or deleted
         write(6,431)(inpone(i2),i2=1,80)
  431    format("#MmMbfile00 ",80a1)
         go to 400

  450    continue
C        All data is in. Close file
         close(unit=10)
         if(iaoc .ne. maxmmdatarow .or. iaob .ne. maxmmdatacol)then
           write(0,453)iaoc,maxmmdatarow,iaob,maxmmdatacol
           write(6,453)iaoc,maxmmdatarow,iaob,maxmmdatacol
 453       format("#WARNING! WARNING! WARNING!  Matrix not full"/
     &            "#iaoc= ",i4,"maxmmdatarow= ",i4/
     &            "#iaob= ",i4,"maxmmdatacol= ",i4/
     &            "# RESETTING maxmmdatarow and maxmmdatacol"/)
           maxmmdatarow=iaoc
           maxmmdatacol=iaob
           endaoc=aoc
           endaob=aob
           write(0,425)endaoc,endaob
           write(6,425)endaoc,endaob
         endif

         deltaaoc=(endaoc-startaoc)/(maxmmdatarow-1)
         deltaaob=(endaob-startaob)/(maxmmdatacol-1)
         write(0,451)deltaaoc,deltaaob
         write(6,451)deltaaoc,deltaaob
  451    format("#MmMbfile00 #DELTAAOC= ",e14.7/
     &          "#MmMbfile00 #DELTAAOB= ",e14.7)
         write(6,452)
         write(0,452)
  452    format("#MmMbfile00: #MmMb00 data input completed. ")
         if(ndatalines .eq. 0)then   ! ? no data lines ?
           write(0,455)
           write(6,455)
  455      format("ERROR: No data lines in file t_MmMb_Surflaw_00a"/
     &            " Stopping")
           iret=455
           return
         endif

      iret=0  !no errors
      return
      end

C====================================================================================
      SUBROUTINE readMmMb90(ivec,iret)
      SAVE
C     ivec= function instruction =0=read in
C     iret= return value = 0 if no errors
C     aoc=  a/c  in mm. of crack depth / half crack surface length 
C     aob=  a/B  in mm. of crack depth / Plate thickness 

C     s/r to read in the Mkm and Mkb for:
C------90 deg   90 deg   90 deg   90 deg   90 deg   90 deg   90 deg   90 deg   90 deg
C      (where 0 deg is along surface of plate, and 90 deg is deepest pt. of crack)

C    The input file looks like this:
C# getMmMb vers. 0.4 starts...
C#ROWS=   51
C#COLS=   11
C#theta=  0.1570796E+01   #radians =  90.00 deg.
C#iaoc iaob a/c a/B         Mm          Mb
C  1  1 0.000  0.00  0.1130000E+01  0.1130000E+01
C  1  2 0.000  0.10  0.1170396E+01  0.1034045E+01
C  1  3 0.000  0.20  0.1307138E+01  0.1016954E+01
C  1  4 0.000  0.30  0.1586888E+01  0.1084638E+01
C  1  5 0.000  0.40  0.2087415E+01  0.1252449E+01
C  1  6 0.000  0.50  0.2917596E+01  0.1539032E+01
C  1  7 0.000  0.60  0.4217416E+01  0.1965316E+01
C  1  8 0.000  0.70  0.6157967E+01  0.2558635E+01
C  1  9 0.000  0.80  0.8941448E+01  0.3361984E+01
C  1 10 0.000  0.90  0.1280117E+02  0.4448406E+01
C  1 11 0.000  1.00  0.1800154E+02  0.5940509E+01
C
C  2  1 0.040  0.00  0.1122352E+01  0.1122352E+01
C  2  2 0.040  0.10  0.1154351E+01  0.1018274E+01
C etc...

      character*300  inp300,jnp300,Cwebpage
      character*1    inpone(300),jnpone(300)
      character*10   inpten(30)
      equivalence (inpone(1), inpten(1), inp300)
      equivalence (jnpone(1),jnp300)

C     Matrices for storing Mm, Mb
      real*4 mb00(51,11),mm00(51,11),mb90(51,11),mm90(51,11)
      integer*4 nmmdatarow,maxmmdatarow, nmmdatacol, maxmmdatacol
C     Limits and intervals of input data used for quicker interpolation
      real*4 startaoc, endaoc, deltaaoc
      real*4 startaob, endaob, deltaaob
      logical debugMm,lactivateMmMb
      common/MMDATA/   mb00,mm00,mb90,mm90,
     &       nmmdatarow,maxmmdatarow, nmmdatacol, maxmmdatacol,
     &      startaoc,endaoc,deltaaoc, startaob,endaob,deltaaob,debugMm,
     &      lactivateMmMb


      ndatalines=0
      ninput=0


C------------------------ Read Input file --------------------------------
C     The matrix max limit values have been set at begin of mainline
      write(0,402)
      write(6,402)
  402 format("# Opening Mm_Mb_90deg. table, file= t_MmMb_Surflaw_90")
      open(unit=10,file= "t_MmMb_Surflaw_90",status="old")

  400 continue     !Loop back to here for next input line.
      read(10,"(a300)",end=450)inp300
      ninput=ninput+1

      if(inp300.eq." ")then    ! Check for blank line
C        write(6,"(a1)")" "
        go to 400
      endif

      if(inpone(1).ne."#")then
C        We may have a data line, or someone screwed up and put the # later in line.
C        See if 1st char is a # later in line
         do 405 i=1,300
           if(inpone(i).eq." ") go to 405
C           No? 1st non-blank found, if # its not a data line
            loc=i
           if(inpone(i).eq."#") then
C            Shift the whole mess over to begining of field
             inew=0
             do 403 j=loc,300
              inew=inew+1
              inpone(inew)=inpone(j)
  403        continue
CdebugMm        write(0,*)"Shifted a comment: ",(inpone(j),j=1,inew)
C            Ok, now its a nice comment. Go play with it.
             go to 430
           else
C            The first non blank is not a #
              go to 410
           endif
  405      continue
           go to 400  !assume garbage in line.

  410      continue
C        1st non blank is not a #  Check if its a number.
         if(inpone(loc).ne."+" .and.
     &      inpone(loc).ne."-" .and.
     &      inpone(loc).ne."." .and.
     &      inpone(loc).ne."0" .and.
     &      inpone(loc).ne."1" .and.
     &      inpone(loc).ne."2" .and.
     &      inpone(loc).ne."3" .and.
     &      inpone(loc).ne."4" .and.
     &      inpone(loc).ne."5" .and.
     &      inpone(loc).ne."6" .and.
     &      inpone(loc).ne."7" .and.
     &      inpone(loc).ne."8" .and.
     &      inpone(loc).ne."9"  )then
C           It must be a letter, not a number. Time to bomb out.
            write(0,415)ninput
            write(6,415)ninput
  415       format(" ERROR readMmMb90: input line no. ",I5," 1st Char.",
     &      " not a # and not a number. Fix data in file mkfile00")
            stop
         endif
C      real*4 mb00(51,11),mm00(51,11),mb90(51,11),mm90(51,11)
C      integer*4 nmmdatarow,maxmmdatarow, nmmdatacol, maxmmdatacol
C        Ok, its a number
         read(inp300,*) iaoc,iaob,aoc,aob, xm,xb
         ndatalines=ndatalines+1
         if(iaoc .gt. maxmmdatarow .or. iaob .gt. maxmmdatacol)then
           write(0,416)iaoc,iaob
           write(6,416)niaoc,iaob
  416      format(" Error: readMmMb90: too many data points:",
     &            "rows: iaoc= ",i5," cols: iaob= "i5/
     &            " recompile plateWeldflaw.f or reduce file data")
           stop
         endif
C        Data is within size of matrix. Place into matrices
         mm90(iaoc,iaob)= xm
         mb90(iaoc,iaob)= xb
         write(6,420)iaoc,iaob,aoc,aob,xm,xb
  420    format("#MmMbfile90 ",i4,i4,2(1x,f6.3),2(1x,f7.4))
         if(iaoc.eq.1 .and. iaob.eq.1)then
            startaoc=aoc
            startaob=aob
            write(0,424)startaoc,startaob
            write(6,424)startaoc,startaob
  424       format("#MmMbfile90 #STARTAOC= ",e14.7/
     &             "#MmMbfile90 #STARTAOB= ",e14.7)
         endif
         if(iaoc.eq.maxmmdatarow .and. iaob .eq. maxmmdatacol)then
            endaoc=aoc
            endaob=aob
            write(0,425)endaoc,endaob
            write(6,425)endaoc,endaob
  425       format("#MmMbfile90 #ENDAOC= ",e14.7/
     &             "#MmMbfile90 #ENDAOB= ",e14.7)
         endif
         go to 400
      endif

  430    continue
C        All comment lines are just written out, or deleted
         write(6,431)(inpone(i2),i2=1,80)
  431    format("#MmMbfile90 ",80a1)
         go to 400

  450    continue
C        All data is in. Close file
         close(unit=10)
        if(iaoc .ne. maxmmdatarow .or. iaob .ne. maxmmdatacol)then
           write(0,453)iaoc,maxmmdatarow,iaob,maxmmdatacol
           write(6,453)iaoc,maxmmdatarow,iaob,maxmmdatacol
 453       format("#WARNING! WARNING! WARNING!  Matrix not full"/
     &            "#iaoc= ",i4,"maxmmdatarow= ",i4/
     &            "#iaob= ",i4,"maxmmdatacol= ",i4/
     &            "# RESETTING maxmmdatarow and maxmmdatacol"/)
           maxmmdatarow=iaoc
           maxmmdatacol=iaob
           endaoc=aoc
           endaob=aob
           write(0,425)endaoc,endaob
           write(6,425)endaoc,endaob
         endif

         deltaaoc=(endaoc-startaoc)/(maxmmdatarow-1)
         deltaaob=(endaob-startaob)/(maxmmdatacol-1)
         write(0,451)deltaaoc,deltaaob
         write(6,451)deltaaoc,deltaaob
  451    format("#MmMbfile90 #DELTAAOC= ",e14.7/
     &          "#MmMbfile90 #DELTAAOB= ",e14.7)
         write(6,452)
         write(0,452)
  452    format("#MmMbfile90: #MmMb90 data input completed. ")
         if(ndatalines .eq. 0)then   ! ? no data lines ?
           write(0,455)
           write(6,455)
  455      format("ERROR: No data lines in file t_MmMb_Surflaw_90a"/
     &            "Stopping")
           iret=455
           return
         endif

      iret=0  !no errors
      return
      end

C=====================================================================
      SUBROUTINE readMkmMkb00(ivec,iret)
      SAVE
C     ivec= function instruction =0=read in
C     iret= return value 
C     aoc=  a/c   input
C     aob=  a/B   input

C     s/r to read the Mkm and Mkb for 0deg
C------00 deg   00 deg   00 deg   00 deg   00 deg   00 deg   00 deg   00 deg   00 deg


C   The calling script (or user) must generate two files based on the 
C   computed problem value of L/B.
C   One file is for the surface crack "c" designated with "_w00_" 
C   A second file is for crack "a" designated with "_w90" in the name

C   For the file format see the Fortran programs getMk_w00.f  getMk_w90.f
C   or see some of the example files such as "t_MkmMkb_w00_LoB=1.0"
C   In those programs the data is written out with the sta.:
C         write(6,400)iaoc,iaob,aoc,aob,LoB,xMkm,xMkb,  fm1,fm2,fm3,f1,f2,f3
C   For us, only the first 7 elements need to be read from each line.
C   Example begining of a file:
C   # getMk_w00 vers. 0.1 starts...
C   #ROWS=  200
C   #COLS=   18
C   #LoB=  1.000
C   #iaoc iaob a/c a/B    L/B    Mkm    Mkb
C     1   1 0.100  0.005  1.00  6.346  6.135  4.707  1.551  0.869  4.758  1.548  0.833
C     1   2 0.100  0.010  1.00  5.247  5.230  3.913  1.535  0.874  4.037  1.555  0.833
C     1   3 0.100  0.015  1.00  4.656  4.709  3.504  1.518  0.876  3.647  1.551  0.832
C     1   4 0.100  0.020  1.00  4.268  4.349  3.236  1.505  0.876  3.386  1.546  0.831

C   For a given L/B ratio all the data will be stored in 4 matrices, each 
C   sized in 200x18  (Rows x Columns)

      integer*4 ivec,iret
      real*4 xmkm,xmkb

      character*300  inp300,jnp300,Cwebpage
      character*1    inpone(300),jnpone(300)
      character*10   inpten(30)
      equivalence (inpone(1), inpten(1), inp300)
      equivalence (jnpone(1),jnp300)

C     Matrices for storing Mkm and Mkb
      real*4 mkb00(18,200),mkm00(18,200),mkb90(18,200),mkm90(18,200)
      integer*4 nmkdatarow,maxmkdatarow, nmkdatacol, maxmkdatacol
C     Limits and intervals of input data used for quicker interpolation
      real*4 startaoc2, endaoc2, deltaaoc2
      real*4 startaob2, endaob2, deltaaob2
      logical debugMk,lactivateMkmMkb
      common/MKDATA/  mkb00,mkm00,mkb90,mkm90,
     &      nmkdatarow,maxmkdatarow, nmkdatacol, maxmkdatacol,
     &      startaoc2,endaoc2,deltaaoc2, startaob2,endaob2,deltaaob2,
     &      debugMk,lactivateMkmMkb


      write(0,402)
      write(6,402)
  402 format("# Opening Mkb_Mkm00 table, file= mkfile00")
      open(unit=10,file="mkfile00",status="old")

      ndatalines=0
      ninput=0
  400 continue     !Loop back to here for next input line.
      read(10,"(a300)",end=450)inp300
      ninput=ninput+1

      if(inp300.eq." ")then    ! Check for blank line
C        write(6,"(a1)")" "
        go to 400
      endif

      if(inpone(1).ne."#")then
C        We may have a data line, or someone screwed up and put the # later in line.
C        See if 1st char is a # later in line
         do 405 i=1,300
           if(inpone(i).eq." ") go to 405
C           No? 1st non-blank found, if # its not a data line
            loc=i
           if(inpone(i).eq."#") then
C            Shift the whole mess over to begining of field
             inew=0
             do 403 j=loc,300
              inew=inew+1
              inpone(inew)=inpone(j)
  403        continue
CdebugMk        write(0,*)"Shifted a comment: ",(inpone(j),j=1,inew)
C            Ok, now its a nice comment. Go play with it.
             go to 430
           else
C            The first non blank is not a #
              go to 410
           endif
  405      continue
           go to 400  !assume garbage in line.

  410      continue
C        1st non blank is not a #  Check if its a number.
         if(inpone(loc).ne."+" .and.
     &      inpone(loc).ne."-" .and.
     &      inpone(loc).ne."." .and.
     &      inpone(loc).ne."0" .and.
     &      inpone(loc).ne."1" .and.
     &      inpone(loc).ne."2" .and.
     &      inpone(loc).ne."3" .and.
     &      inpone(loc).ne."4" .and.
     &      inpone(loc).ne."5" .and.
     &      inpone(loc).ne."6" .and.
     &      inpone(loc).ne."7" .and.
     &      inpone(loc).ne."8" .and.
     &      inpone(loc).ne."9"  )then
C           It must be a letter, not a number. Time to bomb out.
            write(0,415)ninput
            write(6,415)ninput
  415       format(" ERROR mkfile00: input line no. ",I5," 1st Char.",
     &      " not a # and not a number. Fix data in file mkfile00")
            stop
         endif
C        Ok, its a number
         read(inp300,*) iaoc,iaob,aoc,aob,xLob,xmkm,xmkb
         ndatalines=ndatalines+1
         if(iaoc .gt. maxmkdatarow .or. iaob .gt. maxmkdatacol)then
           write(0,416)iaoc,iaob
           write(6,416)iaoc,iaob
  416      format(" Error: mkfile00: too many data points:",
     &            "rows: iaoc= ",i5," cols: iaob= "i5/
     &            " recompile plateWeldflaw.f or reduce mkfile data")
           stop
         endif
C        Data is within size of matrix. Place into matrices
         mkm00(iaoc,iaob)= xmkm
         mkb00(iaoc,iaob)= xmkb
         write(6,420)iaoc,iaob,aoc,aob,xLob,xmkm,xmkb
  420    format("#mkfile00 ",i4,i4,2(1x,f6.3),1x,f5.2,2(1x,e14.7))
         if(iaoc.eq.1 .and. iaob.eq.1)then
            startaoc2=aoc
            startaob2=aob
            write(0,424)startaoc2,startaob2
            write(6,424)startaoc2,startaob2
  424       format("#mkfile00 #STARTAOC= ",e14.7/
     &             "#mkfile00 #STARTAOB= ",e14.7)
         endif
         if(iaoc.eq.maxmkdatarow .and. iaob .eq. maxmkdatacol)then
            endaoc2=aoc
            endaob2=aob
            write(0,425)endaoc2,endaob2
            write(6,425)endaoc2,endaob2
  425       format("#mkfile00 #ENDAOC= ",e14.7/
     &             "#mkfile00 #ENDAOB= ",e14.7)
         endif
         go to 400
      endif

  430    continue
C        All comment lines are just written out, or deleted
         write(6,431)(inpone(i2),i2=1,80)
  431    format("#mkfile00 ",80a1)
         go to 400

  450    continue
C        All data is in. Close file
         close(unit=10)
        if(iaoc .ne. maxmkdatarow .or. iaob .ne. maxmkdatacol)then
           write(0,453)iaoc,maxmkdatarow,iaob,maxmkdatacol
           write(6,453)iaoc,maxmkdatarow,iaob,maxmkdatacol
 453       format("#WARNING! WARNING! WARNING!  Matrix not full"/
     &            "#iaoc= ",i4,"maxmkdatarow= ",i4/
     &            "#iaob= ",i4,"maxmkdatacol= ",i4/
     &            "# RESETTING maxmkdatarow and maxmkdatacol"/)
           maxmkdatarow=iaoc
           maxmkdatacol=iaob
           endaoc2=aoc
           endaob2=aob
           write(0,425)endaoc2,endaob2
           write(6,425)endaoc2,endaob2
         endif

         deltaaoc2=(endaoc2-startaoc2)/(maxmkdatarow-1)
         deltaaob2=(endaob2-startaob2)/(maxmkdatacol-1)
         write(0,451)deltaaoc2,deltaaob2
         write(6,451)deltaaoc2,deltaaob2
  451    format("#mkfile00 #DELTAAOC= ",e14.7/
     &          "#mkfile00 #DELTAAOB= ",e14.7)

         write(6,452)
         write(0,452)
  452    format("#mkfile00: #MkmMkb00 data input completed. ")
         if(ndatalines .eq. 0)then   ! ? no data lines ?
           write(0,455)
           write(6,455)
  455      format("ERROR: No data lines in file mkfile00. Stopping")
           iret=455
           return
         endif

      iret=0  ! no errors
      return
      end



C======================================================================
      SUBROUTINE readMkmMkb90(ivec,iret)
      SAVE
C     ivec= function instruction =0=read in
C     iret= return value 

C     s/r to read in the Mkm and Mkb for 90deg 
C------90 deg   90 deg   90 deg   90 deg   90 deg   90 deg   90 deg   90 deg   90 deg
C        Read in the Mkm and Mkb data file for  90 deg.  Surface crack tip

C   The calling script (or user) must generate two files based on the 
C   computed problem value of L/B.
C   One file is for the surface crack "c" designated with "_w00_" 
C   A second file is for crack "a" designated with "_w90" in the name

C   For the file format see the Fortran programs getMk_w00.f  getMk_w90.f
C   or see some of the example files such as "t_MkmMkb_w00_LoB=1.0"
C   In those programs the data is written out with the sta.:
C         write(6,400)iaoc,iaob,aoc,aob,LoB,xMkm,xMkb,  fm1,fm2,fm3,f1,f2,f3
C   For us, only the first 7 elements need to be read from each line.
C   Example begining of a file:
C   # getMk_w00 vers. 0.1 starts...
C   #ROWS=  200
C   #COLS=   18
C   #LoB=  1.000
C   #iaoc iaob a/c a/B    L/B    Mkm    Mkb
C     1   1 0.100  0.005  1.00  6.346  6.135  4.707  1.551  0.869  4.758  1.548  0.833
C     1   2 0.100  0.010  1.00  5.247  5.230  3.913  1.535  0.874  4.037  1.555  0.833
C     1   3 0.100  0.015  1.00  4.656  4.709  3.504  1.518  0.876  3.647  1.551  0.832
C     1   4 0.100  0.020  1.00  4.268  4.349  3.236  1.505  0.876  3.386  1.546  0.831

C   For a given L/B ratio all the data will be stored in 4 matrices, each 
C   sized in 200x18  (Rows x Columns)

      integer*4 ivec,iret
      real*4 xmkm,xmkb

      character*300  inp300,jnp300,Cwebpage
      character*1    inpone(300),jnpone(300)
      character*10   inpten(30)
      equivalence (inpone(1), inpten(1), inp300)
      equivalence (jnpone(1),jnp300)

C     Matrices for storing Mkm and Mkb
      real*4 mkb00(18,200),mkm00(18,200),mkb90(18,200),mkm90(18,200)
      integer*4 nmkdatarow,maxmkdatarow, nmkdatacol, maxmkdatacol
C     Limits and intervals of input data used for quicker interpolation
      real*4 startaoc2, endaoc2, deltaaoc2
      real*4 startaob2, endaob2, deltaaob2
      logical debugMk,lactivateMkmMkb
      common/MKDATA/  mkb00,mkm00,mkb90,mkm90,
     &      nmkdatarow,maxmkdatarow, nmkdatacol, maxmkdatacol,
     &      startaoc2,endaoc2,deltaaoc2, startaob2,endaob2,deltaaob2,
     &      debugMk,lactivateMkmMkb


      write(0,502)
      write(6,502)
  502 format("# Opening Mkb_Mkm90 table, file= mkfile90")
      open(unit=10,file="mkfile90",status="old")

      ninput=0
  500 continue     !Loop back to here for next input line.
      read(10,"(a300)",end=550)inp300
      ninput=ninput+1

      if(inp300.eq." ")then    ! Check for blank line
C        write(6,"(a1)")" "
        go to 500
      endif

      if(inpone(1).ne."#")then
C        We may have a data line, or someone screwed up and put the # later in line.
C        See if 1st char is a # later in line
         do 505 i=1,300
           if(inpone(i).eq." ") go to 505
C           No? 1st non-blank found, if # its not a data line
            loc=i
           if(inpone(i).eq."#") then
C            Shift the whole mess over to begining of field
             inew=0
             do 503 j=loc,300
              inew=inew+1
              inpone(inew)=inpone(j)
  503        continue
CdebugMk        write(0,*)"Shifted a comment: ",(inpone(j),j=1,inew)
C            Ok, now its a nice comment. Go play with it.
             go to 530
           else
C            The first non blank is not a #
              go to 510
           endif
  505      continue
           go to 500  !assume garbage in line.

  510      continue
C        1st non blank is not a #  Check if its a number.
         if(inpone(loc).ne."+" .and.
     &      inpone(loc).ne."-" .and.
     &      inpone(loc).ne."." .and.
     &      inpone(loc).ne."0" .and.
     &      inpone(loc).ne."1" .and.
     &      inpone(loc).ne."2" .and.
     &      inpone(loc).ne."3" .and.
     &      inpone(loc).ne."4" .and.
     &      inpone(loc).ne."5" .and.
     &      inpone(loc).ne."6" .and.
     &      inpone(loc).ne."7" .and.
     &      inpone(loc).ne."8" .and.
     &      inpone(loc).ne."9"  )then
C           It must be a letter, not a number. Time to bomb out.
            write(0,515)ninput
            write(6,515)ninput
  515       format(" ERROR mkfile90: input line no. ",I5," 1st Char.",
     &      " not a # and not a number. Fix data in file mkfile90")
            stop
         endif
C        Ok, its a number
         read(inp300,*) iaoc,iaob,aoc,aob,xLob,xmkm,xmkb
         ndatalines=ndatalines+1
         if(iaoc .gt. maxmkdatarow .or. iaob .gt. maxmkdatacol)then
           write(0,516)iaoc,iaob
           write(6,516)iaoc,iaob
  516      format(" Error: mkfile90: too many data points:",
     &            "rows: iaoc= ",i5," cols: iaob= "i5/
     &            " recompile plateWeldflaw.f or reduce mkfile data")
           stop
         endif
C        Data is within size of matrix. Place into matrices
         mkm90(iaoc,iaob)= xmkm
         mkb90(iaoc,iaob)= xmkb
         write(6,520)iaoc,iaob,aoc,aob,xLob,xmkm,xmkb
  520    format("#mkfile90 ",i4,i4,2(1x,f6.3),1x,f5.2,2(1x,e14.7))
         if(iaoc.eq.1 .and. iaob.eq.1)then
            startaoc2=aoc
            startaob2=aob
            write(0,524)startaoc2,startaob2
            write(6,524)startaoc2,startaob2
  524       format("#mkfile90 #STARTAOC= ",e14.7/
     &             "#mkfile90 #STARTAOB= ",e14.7)
         endif
         if(iaoc.eq.maxmkdatarow .and. iaob .eq. maxmkdatacol)then
            endaoc2=aoc
            endaob2=aob
            write(0,525)endaoc2,endaob2
            write(6,525)endaoc2,endaob2
  525       format("#mkfile90 #ENDAOC= ",e14.7/
     &             "#mkfile90 #ENDAOB= ",e14.7)
         endif
        go to 500
      endif

  530    continue
C        All comment lines are just written out, or deleted
         write(6,531)(inpone(i2),i2=1,80)
  531    format("#mkfile90 ",80a1)
         go to 500

  550    continue
C        All data is in. Close file
         close(unit=10)
        if(iaoc .ne. maxmkdatarow .or. iaob .ne. maxmkdatacol)then
           write(0,553)iaoc,maxmkdatarow,iaob,maxmkdatacol
           write(6,553)iaoc,maxmkdatarow,iaob,maxmkdatacol
 553       format("#WARNING! WARNING! WARNING!  Matrix not full"/
     &            "#iaoc= ",i4,"maxmkdatarow= ",i4/
     &            "#iaob= ",i4,"maxmkdatacol= ",i4/
     &            "# RESETTING maxmkdatarow and maxmkdatacol"/)
           maxmkdatarow=iaoc
           maxmkdatacol=iaob
           endaoc2=aoc
           endaob2=aob
           write(0,525)endaoc2,endaob2
           write(6,525)endaoc2,endaob2
         endif

         deltaaoc2=(endaoc2-startaoc2)/(maxmkdatarow-1)
         deltaaob2=(endaob2-startaob2)/(maxmkdatacol-1)
         write(0,551)deltaaoc2,deltaaob2
         write(6,551)deltaaoc2,deltaaob2
  551    format("#mkfile90 #DELTAAOC= ",e14.7/
     &          "#mkfile90 #DELTAAOB= ",e14.7)

         write(6,552)
         write(0,552)
  552    format("#mkfile90: #MkmMkb90 data input completed. ")
         if(ndatalines .eq. 0)then   ! ? no data lines ?
           write(0,555)
           write(6,555)
  555      format("ERROR: No data lines in file mkfile90. Stopping")
           iret=555
           return
         endif

         iret=0  !no errors
      return
      end

C=========================================================================

C getfw.f   vers 0.4  Surface flaw Finite Width Corr Factor  Oct 28 2012
      SUBROUTINE fwSurfFlaw(ivec,iret,cow,aob,xfw)
      SAVE
C  ivec=0=create Matrix,  ivec=1=interpolate
C Create the table of fw values for a surface flaw as per BS7910 pg.185
C    and if ivec=1  interpolate for xfw  and return to mainline
C c/W  is 1/2 surf crack length / plate Width
C a/B  is   crack depth/ thickness
C Standalone compile:   gfortran -g -w  getfw.f  -o getfw
C Usage:    getfw  >  outfile

C For plot output file :
C       grep #plotfw outfile | delete1arg |delete1arg >fwData4Plot
C   then in gnuplot do:
C       set grid
C       set term x11 enhanced font "arial,15"
C       set xlabel "c/W"
C       set ylabel "a/B"
C       set zlabel "fw" rotate by 90
C       set title "Surface Flaw Finite Width Correction"
C       set title "Plate Surface Flaw Finite Width Correction"
C       splot "fwData4Plot" u 3:4:5
C For Matrix viewing:
C       grep -v #plotfw outfile | delete1arg > t_fw_SurfFlawMatrix
C       vi t_fw_SurfFlawMatrix

C  Copyright (C) 2012  F.A.Conle
C  This program is free software; you can redistribute it and/or
C  modify it under the terms of the GNU General Public License as
C  published by the Free Software Foundation; either version 2 of the
C  license, or (at your option) any later version.
C  This program is distributed in the hope tha it will be useful,
C  but WITHOUT ANY WARRANTY; without even the implied warranty of
C  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
C  GNU General PUblic License for more details.
C  You should have received a copy of the GNU General PUblic License
C  along with this program; if not, write to the Free Software
C  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
C  Try also their web site: http://www.gnu.org/copyleft/gpl.html

C There are two variables that define the matrix of fw
C   1. cow :   c/W     where W= plate width,  2c= crack width at surface
C   2. aob  :  a/B     where a is crack depth, B= plate thickness

C A matrix is created by this program, also the plot file information.


      integer*4 ivec,iret

C     Matrix for storing  fw
      real*4 fw(26,26)
      integer*4 nfwdatarow,maxfwdatarow, nfwdatacol, maxfwdatacol
C     Limits and intervals of input data used for quicker interpolation
      real*4 startcow, endcow, deltacow
      real*4 startaob3, endaob3, deltaaob3
      logical debugfw,lactivatefw
      common/FWDATA/ fw
     &     nfwdatarow,maxfwdatarow, nfwdatacol, maxfwdatacol,
     &     startcow,endcow,deltacow, startaob3,endaob3,deltaaob3,debugfw
     &     ,lactivatefw

      iret=0 ! Change this if there is an error

      if(ivec.eq.1)go to 3000  !go and interpolate

C     Check on BS standard limits for aob and cow

C     ivec=0  Initilize the matrix and other variables
      nrows=26
      ncols=26
      maxfwdatarow=nrows  !save in common block
      maxfwdatacol=ncols

      startaob3=0.0
      endaob3=1.0
      deltaaob3= (endaob3-startaob3)/(float(ncols-1))  ! (1.0-0.)/25 = 0.04

      startcow=0
      endcow=0.40
      deltacow= 0.40/(float(nrows-1))  ! = 0.016

      pi=3.1415927
      write(6,10)nrows,ncols
   10 format("#fw # getfw vers. 0.4 starts..."/
     &   "#fw #ROWS= ",i4/"#fw #COLS= ",i4/
     &   "##fw a/b runs between 0.0  and 1.0, c/W between 0.0 and 0.4")

      write(6,25)
C   25 format("#fw #iao2c  iaob   a/2c   a/B     Mm   phi")
   25 format("#fw #icow c/W                                     a/B ")
      write(6,26)startaob3,endaob3
   26 format("#fw         ",f5.3,196x,f5.3)

C     Distance between a/B points is:
C     If there are 26 locations, there are 26-1 intervals between them
      write(6,30)startaob3,endaob3,deltaaob3
   30 format("#fw #startaob3,endaob3,deltaaob3 = ",3(f6.4,1x))

C     Loop for the c/W  variable.
      write(6,32)deltacow
   32 format("#fw #deltacow= ",f6.4)
      cow=startcow
C     cow gets incremented at end of do loop
      do 2000 icow=1,nrows    ! ----------------------loop  cow----------------

C     Loop for the a/B  variable.
      aob=startaob3
      do 1000 iaob=1,ncols    ! ----------------------loop  a/B----------------
C      aob will be incremented at end of loop

C     Ok, generate all the parameters

      if(cow .ge. 0. .and. cow .le. 1.0)then
        temp=(pi*cow)*sqrt(aob)
        ysecant=1.0/cos(temp)   ! note that sec(a)=  1.0/cos(a)
        xfw=sqrt(ysecant)
        fw(icow,iaob)= xfw
        write(6,50)icow,iaob,cow,aob,xfw
   50   format("#fw #plotfw ",i4,1x,i4,1x,f6.4,1x,f6.4,2x,e13.6)

        if(icow .eq. 1 .and. iaob .eq. 1)then
          write(6,54)startcow,startaob3
   54     format("#fw #STARTCOW= ",e14.7/"#fw #STARTAOB= ",e14.7)
        endif
      if(icow.eq.maxfwdatarow .and. iaob.eq.maxdatacol)then
         write(0,2050)startcow,endcow,deltacow
         write(6,2050)startcow,endcow,deltacow
 2050    format("#fw #STARTCOW= ",e14.7/"#fw #ENDCOW= ",e14.7/
     &          "#fw #DELTACOW= ",e14.7)
         write(0,2052)startaob3,endaob3,deltaaob3
         write(6,2052)startaob3,endaob3,deltaaob3
 2052    format("#fw #STARTAOB= ",e14.7/"#fw #ENDAOB= ",e14.7/
     &          "#fw #DELTAAOB= ",e14.7)
      endif

        go to 950
      endif

C     We should not ever end up here
  450  write(0,*)"# Error near Sta.No. 450 in prog getfw...Stopping."
       write(0,*)"# Call the programmer."
       stop

C     End of loop for aob
  950 continue
      aob=aob+deltaaob3
 1000 continue

C     One row is done, write it out for the table
      write(6,470)icow,cow,(fw(icow,j),j=1,ncols)
  470 format("#fw",i3,1x,f4.3,2x,50(f6.3,1x))  ! not all are used, hopefully

      cow=cow+deltacow
      write(6,475)         !write out a blank line for cow plot seperation
  475 format("#fw #plotfw")
 2000 continue

      write(0,*)"#fw  Finished creating fw Matrix "
      iret=0
      return



C================== Interpolation ===================================
 3000 continue
      if(debugfw)then
        write(0,3010)
 3010   format(" Enter c/W  and  a/B : ",$)
        read(5,*,end=9000)cow,aob
      endif
C     if not debug,  cow and  aob  are passed into s/r

      if(cow .le.0. .and. aob .le.0.)then
        write(0,3020)cow,aob
 3020   format("#fw #Error: fwSurfFlaw: c/W,a/B = ",e14.7,",",e14.7/
     &         "#fw #Stopping...")
        iret=3020   !stop. give mainline a chance to exit gracefully.
        return
      endif

      i=ifix((cow-startcow)/deltacow)+1
      j=ifix((aob-startaob3)/deltaaob3)+1
      if(i.lt.1 .or. j.lt.1 .or. j.gt.maxfwdatacol .or.
     &   i.gt. maxfwdatarow) then
C        Out of bounds error
         write(0,3025)startcow,cow,endcow,
     &                startaob3,aob3,endaob3,i,j
 3025    format("#ERROR: S/R getfw c/W or a/B out of bounds:"/
     &    "#      start c/W=",f6.3," c/W= ",e14.7," end c/W= ",f6.3/
     &    "#      start a/B=",f6.3," a/B= ",e14.7," end a/B= ",f6.3/
     &    "#      i,j=  ",i5,1x,i5/
     &    "# Stopping...")
          iret=3025    ! set the error flag to format sta. no.
          return
      endif

C     j,i  is the corner (see internet address above)  of x1,y1
      ip1=i+1
      jp1=j+1
C     We need to use x1, x2, y1, y2 to calculate Mm and Mb
C     x,y  are aob,cow
      x=aob
      y=cow

C     Things appear to be within bounds of matrices, continue
      x1=startaob3+float(j-1)*deltaaob3
      x2=x1+deltaaob3
      y1=startcow + float(i-1)*deltacow
      y2=y1+deltacow
      if(debugfw)then
        write(0,3035)x1,y1,  x2,y1, x,y, x1,y2, x2,y2
        write(6,3035)x1,y1,  x2,y1, x,y, x1,y2, x2,y2
 3035   format("#fw #TargetCo-ords:"/
     &        "#fw #x1,y1       x2,y1  :",2f7.4,14x,2f7.4/
     &        "#fw #       x,y         :",15x,2f7.4/
     &        "#fw #x1,y2       x2,y2  :",2f7.4,14x,2f7.4/
     &  )
        write(0,3036)i,j,  i,jp1,  ip1,j, ip1,jp1
        write(6,3036)i,j,  i,jp1,  ip1,j, ip1,jp1
 3036   format("#fw # i,j       i,j+1    : "i3,",",i3, 10x, i3,",",i3/
     &         "#fw # i+1,j     i+1,j+1  : "i3,",",i3, 10x, i3,",",i3/
     &  )
      endif

      Q11=fw(i,j)
      Q12=fw(ip1,j)
      Q21=fw(i,jp1)
      Q22=fw(ip1,jp1)

C     Ok, lets find  R1 on the line between q11 and q21
C     Original formula is:
C      R1= ( (x2-x)/(x2-x1))*Q11 + ((x-x1)/(x2-x1))*Q21
C      R2= ( (x2-x)/(x2-x1))*Q12 + ((x-x1)/(x2-x1))*Q22
C
      x2mx=x2-x
      x2mx1 = x2-x1
      xmx1= x-x1
      frac1= x2mx/x2mx1
      frac2= xmx1/x2mx1

C      R1=(x2mx/x2mx1)*Q11 + (xmx1/x2mx1)*Q21
C      R2=(x2mx/x2mx1)*Q12 + (xmx1/x2mx1)*Q22
      R1 = frac1*Q11 + frac2*Q21
      R2 = frac1*Q12 + frac2*Q22

      y2my1=y2-y1
      frac1y= (y2-y)/y2my1
      frac2y= (y-y1)/y2my1
C      xmm = ( (y2-y)/y2my1 )*R1 + ( (y-y1)/y2my1 )*R2
      xfw = frac1y*R1 + frac2y*R2
      if(debugfw)then
        write(0,3040)cow,aob,i,j, Q11,R1,Q21, xfw, Q12,R2,Q22
        write(6,3040)cow,aob,i,j, Q11,R1,Q21, xfw, Q12,R2,Q22
 3040   format("#fw #Solution for c/W= ",f6.3," a/B= ",f6.3,
     &        " (i,j)=",2i3/
     &        "#fw # Q11,  R1,  Q21 :  ",3(f7.4,1x)/
     &        "#fw #       fw =     :  ",10x,f7.4/
     &        "#fw # Q12,  R2,  Q22 :  ",3(f7.4,1x)/
     &        )
      endif

 9000 continue
      iret=0
      return

      end
