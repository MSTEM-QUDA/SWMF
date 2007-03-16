#!MC 1000

### set useful constants
$!Varset |PI| = (2.*asin(1.))
$!Varset |d2r| = (|PI|/180.)
$!Varset |r2d| = (180./|PI|)

### apply style
$!READSTYLESHEET  "style.sty" 
  INCLUDEPLOTSTYLE = YES
  INCLUDETEXT = YES
  INCLUDEGEOM = YES
  INCLUDEAUXDATA = YES
  INCLUDESTREAMPOSITIONS = YES
  INCLUDECONTOURLEVELS = YES
  MERGE = NO
  INCLUDEFRAMESIZEANDPOSITION = YES

### turn on grid on slices
#$!FIELD [1]  MESH{COLOR = BLACK}
#$!FIELD [1]  MESH{SHOW = YES}
#$!FIELD [1]  MESH{LINETHICKNESS = 0.1}

### variable to plot
$!GLOBALCONTOUR 1  VAR = 20

### reset contours
$!RUNMACROFUNCTION  "Reset Contours (MIN/MAX)" 

### set manual contour range
#$!CONTOURLEVELS NEW
#  RAWDATA
#1
#0.
#$!LOOP 200
#  $!VarSet |ContToAdd| = (0. + (|LOOP| * ((1.-0.)/200.) ) )
#  $!CONTOURLEVELS ADD
#    RAWDATA
#  1
#  |ContToAdd|
#$!ENDLOOP

$!GLOBALCONTOUR 1  LEGEND{BOX{BOXTYPE = FILLED}}

#$!ATTACHTEXT 
#  XYPOS
#    {
#    X = 1
#    Y = 1.5
#    }
#  TEXTSHAPE
#    {
#    HEIGHT = 24
#    }
#  ATTACHTOZONE = NO
#  ANCHOR = LEFT
#  TEXT = ''
#  COLOR = BLACK

### save file
$!PAPER ORIENTPORTRAIT = YES
$!PRINTSETUP PALETTE = COLOR
$!PRINTSETUP SENDPRINTTOFILE = YES
$!PRINTSETUP PRINTFNAME = 'print.cps'
$!PRINT 
