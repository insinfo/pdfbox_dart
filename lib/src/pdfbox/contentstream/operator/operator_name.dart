class OperatorName {
  // Non stroking color
  static const String nonStrokingColor = 'sc';
  static const String nonStrokingColorN = 'scn';
  static const String nonStrokingRgb = 'rg';
  static const String nonStrokingGray = 'g';
  static const String nonStrokingCmyk = 'k';
  static const String nonStrokingColorspace = 'cs';

  // Stroking color
  static const String strokingColor = 'SC';
  static const String strokingColorN = 'SCN';
  static const String strokingColorRgb = 'RG';
  static const String strokingColorGray = 'G';
  static const String strokingColorCmyk = 'K';
  static const String strokingColorspace = 'CS';

  // Marked content
  static const String beginMarkedContentSeq = 'BDC';
  static const String beginMarkedContent = 'BMC';
  static const String endMarkedContent = 'EMC';
  static const String markedContentPointWithProps = 'DP';
  static const String markedContentPoint = 'MP';
  static const String drawObject = 'Do';

  // Graphics state
  static const String concat = 'cm';
  static const String restore = 'Q';
  static const String save = 'q';
  static const String setFlatness = 'i';
  static const String setGraphicsStateParams = 'gs';
  static const String setLineCapstyle = 'J';
  static const String setLineDashpattern = 'd';
  static const String setLineJoinstyle = 'j';
  static const String setLineMiterlimit = 'M';
  static const String setLineWidth = 'w';
  static const String setMatrix = 'Tm';
  static const String setRenderingintent = 'ri';
  static const String setSmoothness = 'sm';

  // Graphics operators
  static const String appendRect = 're';
  static const String beginInlineImage = 'BI';
  static const String beginInlineImageData = 'ID';
  static const String endInlineImage = 'EI';
  static const String clipEvenOdd = 'W*';
  static const String clipNonZero = 'W';
  static const String closeAndStroke = 's';
  static const String closeFillEvenOddAndStroke = 'b*';
  static const String closeFillNonZeroAndStroke = 'b';
  static const String closePath = 'h';
  static const String curveTo = 'c';
  static const String curveToReplicateFinalPoint = 'y';
  static const String curveToReplicateInitialPoint = 'v';
  static const String endPath = 'n';
  static const String fillEvenOddAndStroke = 'B*';
  static const String fillEvenOdd = 'f*';
  static const String fillNonZeroAndStroke = 'B';
  static const String fillNonZero = 'f';
  static const String legacyFillNonZero = 'F';
  static const String lineTo = 'l';
  static const String moveTo = 'm';
  static const String shadingFill = 'sh';
  static const String strokePath = 'S';

  // Text operators
  static const String beginText = 'BT';
  static const String endText = 'ET';
  static const String moveText = 'Td';
  static const String moveTextSetLeading = 'TD';
  static const String nextLine = 'T*';
  static const String setCharSpacing = 'Tc';
  static const String setFontAndSize = 'Tf';
  static const String setTextHorizontalScaling = 'Tz';
  static const String setTextLeading = 'TL';
  static const String setTextRenderingmode = 'Tr';
  static const String setTextRise = 'Ts';
  static const String setWordSpacing = 'Tw';
  static const String showText = 'Tj';
  static const String showTextAdjusted = 'TJ';
  static const String showTextLine = "'";
  static const String showTextLineAndSpace = '"';

  // Type3 font operators
  static const String type3d0 = 'd0';
  static const String type3d1 = 'd1';

  // Compatibility section
  static const String beginCompatibilitySection = 'BX';
  static const String endCompatibilitySection = 'EX';

  const OperatorName._();
}
