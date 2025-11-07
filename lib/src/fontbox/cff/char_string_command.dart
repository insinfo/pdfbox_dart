/// Command set used by Type 1/Type 2 CharStrings.
enum CharStringCommand {
  hstem(Type1KeyWord.hstem, Type2KeyWord.hstem, 1),
  vstem(Type1KeyWord.vstem, Type2KeyWord.vstem, 3),
  vmoveto(Type1KeyWord.vmoveto, Type2KeyWord.vmoveto, 4),
  rlineto(Type1KeyWord.rlineto, Type2KeyWord.rlineto, 5),
  hlineto(Type1KeyWord.hlineto, Type2KeyWord.hlineto, 6),
  vlineto(Type1KeyWord.vlineto, Type2KeyWord.vlineto, 7),
  rrcurveto(Type1KeyWord.rrcurveto, Type2KeyWord.rrcurveto, 8),
  closepath(Type1KeyWord.closepath, null, 9),
  callsubr(Type1KeyWord.callsubr, Type2KeyWord.callsubr, 10),
  ret(Type1KeyWord.ret, Type2KeyWord.ret, 11),
  escape(Type1KeyWord.escape, Type2KeyWord.escape, 12),
  hsbw(Type1KeyWord.hsbw, null, 13),
  endchar(Type1KeyWord.endchar, Type2KeyWord.endchar, 14),
  hstemhm(null, Type2KeyWord.hstemhm, 18),
  hintmask(null, Type2KeyWord.hintmask, 19),
  cntrmask(null, Type2KeyWord.cntrmask, 20),
  rmoveto(Type1KeyWord.rmoveto, Type2KeyWord.rmoveto, 21),
  hmoveto(Type1KeyWord.hmoveto, Type2KeyWord.hmoveto, 22),
  vstemhm(null, Type2KeyWord.vstemhm, 23),
  rcurveline(null, Type2KeyWord.rcurveline, 24),
  rlinecurve(null, Type2KeyWord.rlinecurve, 25),
  vvcurveto(null, Type2KeyWord.vvcurveto, 26),
  hhcurveto(null, Type2KeyWord.hhcurveto, 27),
  shortint(null, Type2KeyWord.shortint, 28),
  callgsubr(null, Type2KeyWord.callgsubr, 29),
  vhcurveto(Type1KeyWord.vhcurveto, Type2KeyWord.vhcurveto, 30),
  hvcurveto(Type1KeyWord.hvcurveto, Type2KeyWord.hvcurveto, 31),
  dotsection(Type1KeyWord.dotsection, null, _escapePrefix | 0),
  vstem3(Type1KeyWord.vstem3, null, _escapePrefix | 1),
  hstem3(Type1KeyWord.hstem3, null, _escapePrefix | 2),
  andCommand(null, Type2KeyWord.andCommand, _escapePrefix | 3),
  orCommand(null, Type2KeyWord.orCommand, _escapePrefix | 4),
  notCommand(null, Type2KeyWord.notCommand, _escapePrefix | 5),
  seac(Type1KeyWord.seac, null, _escapePrefix | 6),
  sbw(Type1KeyWord.sbw, null, _escapePrefix | 7),
  absCommand(null, Type2KeyWord.absCommand, _escapePrefix | 9),
  add(null, Type2KeyWord.add, _escapePrefix | 10),
  sub(null, Type2KeyWord.sub, _escapePrefix | 11),
  div(Type1KeyWord.div, Type2KeyWord.div, _escapePrefix | 12),
  neg(null, Type2KeyWord.neg, _escapePrefix | 14),
  eq(null, Type2KeyWord.eq, _escapePrefix | 15),
  callothersubr(Type1KeyWord.callothersubr, null, _escapePrefix | 16),
  pop(Type1KeyWord.pop, null, _escapePrefix | 17),
  drop(null, Type2KeyWord.drop, _escapePrefix | 18),
  put(null, Type2KeyWord.put, _escapePrefix | 20),
  get(null, Type2KeyWord.get, _escapePrefix | 21),
  ifelse(null, Type2KeyWord.ifelse, _escapePrefix | 22),
  random(null, Type2KeyWord.random, _escapePrefix | 23),
  mul(null, Type2KeyWord.mul, _escapePrefix | 24),
  sqrt(null, Type2KeyWord.sqrt, _escapePrefix | 26),
  dup(null, Type2KeyWord.dup, _escapePrefix | 27),
  exch(null, Type2KeyWord.exch, _escapePrefix | 28),
  stackIndex(null, Type2KeyWord.stackIndex, _escapePrefix | 29),
  roll(null, Type2KeyWord.roll, _escapePrefix | 30),
  setcurrentpoint(Type1KeyWord.setcurrentpoint, null, _escapePrefix | 33),
  hflex(null, Type2KeyWord.hflex, _escapePrefix | 34),
  flex(null, Type2KeyWord.flex, _escapePrefix | 35),
  hflex1(null, Type2KeyWord.hflex1, _escapePrefix | 36),
  flex1(null, Type2KeyWord.flex1, _escapePrefix | 37),
  unknown(null, null, -1);

  const CharStringCommand(this.type1KeyWord, this.type2KeyWord, this.value);

  final Type1KeyWord? type1KeyWord;
  final Type2KeyWord? type2KeyWord;
  final int value;

  static const int _escapeByte = 12;
  static const int _escapePrefix = _escapeByte << 8;
  static final Map<int, CharStringCommand> _singleByteCommands =
      _buildSingleByteLookup();
  static final Map<int, CharStringCommand> _escapedCommands =
      _buildEscapedLookup();

  static Map<int, CharStringCommand> _buildSingleByteLookup() {
    final map = <int, CharStringCommand>{};
    for (final command in CharStringCommand.values) {
      if (command.value >= 0 && command.value < _escapePrefix) {
        map[command.value] = command;
      }
    }
    return map;
  }

  static Map<int, CharStringCommand> _buildEscapedLookup() {
    final map = <int, CharStringCommand>{};
    for (final command in CharStringCommand.values) {
      if (command.value >= _escapePrefix) {
        map[command.value & 0xFF] = command;
      }
    }
    return map;
  }

  /// Returns the command encoded by [b0].
  static CharStringCommand fromByte(int b0) {
    final command = _singleByteCommands[b0];
    return command ?? CharStringCommand.unknown;
  }

  /// Returns the command encoded by the escape sequence `12 b1`.
  static CharStringCommand fromEscapedByte(int b1) {
    final command = _escapedCommands[b1];
    return command ?? CharStringCommand.unknown;
  }

  /// Resolves the command encoded by [bytes].
  static CharStringCommand fromBytes(List<int> bytes) {
    if (bytes.isEmpty) {
      return CharStringCommand.unknown;
    }
    if (bytes.length == 1) {
      return fromByte(bytes[0]);
    }
    if (bytes[0] != _escapeByte) {
      return CharStringCommand.unknown;
    }
    return fromEscapedByte(bytes[1]);
  }

  bool get isEscape => value >= _escapePrefix;
}

/// Type 1 keywords for CharString commands.
enum Type1KeyWord {
  hstem,
  vstem,
  vmoveto,
  rlineto,
  hlineto,
  vlineto,
  rrcurveto,
  closepath,
  callsubr,
  ret,
  escape,
  hsbw,
  endchar,
  rmoveto,
  hmoveto,
  vhcurveto,
  hvcurveto,
  dotsection,
  vstem3,
  hstem3,
  seac,
  sbw,
  div,
  callothersubr,
  pop,
  setcurrentpoint,
}

/// Type 2 keywords for CharString commands.
enum Type2KeyWord {
  hstem,
  vstem,
  vmoveto,
  rlineto,
  hlineto,
  vlineto,
  rrcurveto,
  callsubr,
  ret,
  escape,
  endchar,
  hstemhm,
  hintmask,
  cntrmask,
  rmoveto,
  hmoveto,
  vstemhm,
  rcurveline,
  rlinecurve,
  vvcurveto,
  hhcurveto,
  shortint,
  callgsubr,
  vhcurveto,
  hvcurveto,
  andCommand,
  orCommand,
  notCommand,
  absCommand,
  add,
  sub,
  div,
  neg,
  eq,
  drop,
  put,
  get,
  ifelse,
  random,
  mul,
  sqrt,
  dup,
  exch,
  stackIndex,
  roll,
  hflex,
  flex,
  hflex1,
  flex1,
}
