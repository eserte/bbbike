LAYER
  NAME Sternfahrt
  GROUP sternfahrt
  TYPE LINE
  STATUS ON
  DATA sternfahrt2004

  TOLERANCE 3

  CLASSITEM "CAT" 
  CLASS
    NAME "Sternfahrt-Route"
    EXPRESSION /./
    COLOR 0 0 0
    SYMBOL 'dotted5'
    SIZE 7
  END
END

LAYER
  NAME Treffpunkte
  GROUP treffpunkte
  TYPE ANNOTATION
  STATUS ON
  DATA treffpunkte2004

  LABELITEM "NAME"

  TOLERANCE 3

  CLASSITEM "CAT" 
  CLASS
    EXPRESSION /./
    LABEL
      MINFEATURESIZE 50
      MINDISTANCE 150
      POSITION AUTO
      TYPE truetype
      FONT "lucida"
      SIZE 10
      COLOR 170 0 0
      OUTLINECOLOR 225 225 225
    END
  END
END
