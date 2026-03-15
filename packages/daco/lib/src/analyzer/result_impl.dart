// ignore_for_file: public_member_api_docs

import 'package:analyzer/diagnostic/diagnostic.dart';

import 'analysis_session.dart';
import 'block.dart';
import 'result.dart';

class ParsedBlockResultImpl extends ParsedBlockResult {
  ParsedBlockResultImpl(this.block, this.errors, this.session);

  @override
  final Block block;

  @override
  final List<Diagnostic> errors;

  @override
  final DacoAnalysisSession session;
}

class ParseStringResultImpl extends ParseStringResult {
  ParseStringResultImpl({required this.block, required this.errors});

  @override
  final Block block;

  @override
  final List<Diagnostic> errors;
}
