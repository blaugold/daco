// Adapted from the Dart SDK for use in an analyzer plugin.

// Copyright (c) 2014, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: non_constant_identifier_names, implementation_imports, cascade_invocations, lines_longer_than_80_chars, public_member_api_docs, flutter_style_todos

import 'dart:math' as math;

import 'package:_fe_analyzer_shared/src/parser/quote.dart'
    show analyzeQuote, Quote, firstQuoteLength, lastQuoteLength;
import 'package:_fe_analyzer_shared/src/scanner/characters.dart' as char;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer/src/dart/ast/extensions.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' hide Element;

/// A computer for [HighlightRegion]s and in a Dart [CompilationUnit].
class DartUnitHighlightsComputer {
  /// Creates a computer for [HighlightRegion]s and in a Dart [CompilationUnit].
  ///
  /// If [range] is supplied, tokens outside of this range will not be included
  /// in results.
  DartUnitHighlightsComputer(this._unit, {this.range});
  final CompilationUnit _unit;
  final SourceRange? range;

  final _regions = <HighlightRegion>[];
  bool _computeRegions = false;

  /// Returns the computed highlight regions, not `null`.
  List<HighlightRegion> compute() {
    _reset();
    _computeRegions = true;
    _unit.accept(_DartUnitHighlightsComputerVisitor(this));
    _addCommentRanges();
    return _regions;
  }

  void _addCommentRanges() {
    Token? token = _unit.beginToken;
    while (token != null) {
      Token? commentToken = token.precedingComments;
      while (commentToken != null) {
        HighlightRegionType? highlightType;
        if (commentToken.type == TokenType.MULTI_LINE_COMMENT) {
          if (commentToken.lexeme.startsWith('/**')) {
            highlightType = HighlightRegionType.COMMENT_DOCUMENTATION;
          } else {
            highlightType = HighlightRegionType.COMMENT_BLOCK;
          }
        }
        if (commentToken.type == TokenType.SINGLE_LINE_COMMENT) {
          if (commentToken.lexeme.startsWith('///')) {
            highlightType = HighlightRegionType.COMMENT_DOCUMENTATION;
          } else {
            highlightType = HighlightRegionType.COMMENT_END_OF_LINE;
          }
        }
        if (highlightType != null) {
          _addRegion_token(commentToken, highlightType);
        }
        commentToken = commentToken.next;
      }
      if (token.type == TokenType.EOF) {
        // Only exit the loop *after* processing the EOF token as it may
        // have preceding comments.
        break;
      }
      token = token.next;
    }
  }

  void _addIdentifierRegion(SimpleIdentifier node) {
    if (_addIdentifierRegion_keyword(node)) {
      return;
    }
    if (_addIdentifierRegion_class(node)) {
      return;
    }
    if (_addIdentifierRegion_extension(node)) {
      return;
    }
    if (_addIdentifierRegion_constructor(node)) {
      return;
    }
    if (_addIdentifierRegion_getterSetterDeclaration(node)) {
      return;
    }
    if (_addIdentifierRegion_field(node)) {
      return;
    }
    if (_addIdentifierRegion_dynamicLocal(node)) {
      return;
    }
    if (_addIdentifierRegion_function(node)) {
      return;
    }
    if (_addIdentifierRegion_importPrefix(node)) {
      return;
    }
    if (_addIdentifierRegion_label(node)) {
      return;
    }
    if (_addIdentifierRegion_localVariable(node)) {
      return;
    }
    if (_addIdentifierRegion_method(node)) {
      return;
    }
    if (_addIdentifierRegion_parameter(node)) {
      return;
    }
    if (_addIdentifierRegion_typeAlias(node)) {
      return;
    }
    if (_addIdentifierRegion_typeParameter(node)) {
      return;
    }
    if (_addIdentifierRegion_unresolvedInstanceMemberReference(node)) {
      return;
    }
    _addRegion_node(node, HighlightRegionType.IDENTIFIER_DEFAULT);
  }

  void _addIdentifierRegion_annotation(Annotation node) {
    final arguments = node.arguments;
    if (arguments == null) {
      _addRegion_node(node, HighlightRegionType.ANNOTATION);
    } else {
      _addRegion_nodeStart_tokenEnd(
        node,
        arguments.beginToken,
        HighlightRegionType.ANNOTATION,
      );
      _addRegion_token(arguments.endToken, HighlightRegionType.ANNOTATION);
    }
  }

  bool _addIdentifierRegion_class(SimpleIdentifier node) {
    final element = node.writeOrReadElement;
    if (element is! ClassElement) {
      return false;
    }
    // prepare type
    HighlightRegionType type;
    final parent = node.parent;
    final grandParent = parent?.parent;
    if (parent is NamedType &&
        grandParent is ConstructorName &&
        grandParent.parent is InstanceCreationExpression) {
      // new Class()
      type = HighlightRegionType.CONSTRUCTOR;
    } else if (element.isEnum) {
      type = HighlightRegionType.ENUM;
    } else {
      type = HighlightRegionType.CLASS;
    }

    // add region
    return _addRegion_node(
      node,
      type,
    );
  }

  bool _addIdentifierRegion_constructor(SimpleIdentifier node) {
    final element = node.writeOrReadElement;
    if (element is! ConstructorElement) {
      return false;
    }
    return _addRegion_node(
      node,
      HighlightRegionType.CONSTRUCTOR,
    );
  }

  bool _addIdentifierRegion_dynamicLocal(SimpleIdentifier node) {
    final element = node.writeOrReadElement;
    if (element is LocalVariableElement) {
      final elementType = element.type;
      if (elementType.isDynamic) {
        final type = node.inDeclarationContext()
            ? HighlightRegionType.DYNAMIC_LOCAL_VARIABLE_DECLARATION
            : HighlightRegionType.DYNAMIC_LOCAL_VARIABLE_REFERENCE;
        return _addRegion_node(node, type);
      }
    }
    if (element is ParameterElement) {
      final elementType = element.type;
      if (elementType.isDynamic) {
        final type = node.inDeclarationContext()
            ? HighlightRegionType.DYNAMIC_PARAMETER_DECLARATION
            : HighlightRegionType.DYNAMIC_PARAMETER_REFERENCE;
        return _addRegion_node(node, type);
      }
    }
    return false;
  }

  bool _addIdentifierRegion_extension(SimpleIdentifier node) {
    final element = node.writeOrReadElement;
    if (element is! ExtensionElement) {
      return false;
    }

    return _addRegion_node(
      node,
      HighlightRegionType.EXTENSION,
    );
  }

  bool _addIdentifierRegion_field(SimpleIdentifier node) {
    final element = node.writeOrReadElement;
    // prepare type
    HighlightRegionType? type;
    if (element is FieldElement) {
      if (element.isEnumConstant) {
        type = HighlightRegionType.ENUM_CONSTANT;
      } else if (element.isStatic) {
        type = HighlightRegionType.STATIC_FIELD_DECLARATION;
      } else {
        type = node.inDeclarationContext()
            ? HighlightRegionType.INSTANCE_FIELD_DECLARATION
            : HighlightRegionType.INSTANCE_FIELD_REFERENCE;
      }
    } else if (element is TopLevelVariableElement) {
      type = HighlightRegionType.TOP_LEVEL_VARIABLE_DECLARATION;
    }
    if (element is PropertyAccessorElement) {
      final accessor = element;
      final variable = accessor.variable;
      if (variable is TopLevelVariableElement) {
        type = accessor.isGetter
            ? HighlightRegionType.TOP_LEVEL_GETTER_REFERENCE
            : HighlightRegionType.TOP_LEVEL_SETTER_REFERENCE;
      } else if (variable is FieldElement && variable.isEnumConstant) {
        type = HighlightRegionType.ENUM_CONSTANT;
      } else if (accessor.isStatic) {
        type = accessor.isGetter
            ? HighlightRegionType.STATIC_GETTER_REFERENCE
            : HighlightRegionType.STATIC_SETTER_REFERENCE;
      } else {
        type = accessor.isGetter
            ? HighlightRegionType.INSTANCE_GETTER_REFERENCE
            : HighlightRegionType.INSTANCE_SETTER_REFERENCE;
      }
    }
    // add region
    if (type != null) {
      return _addRegion_node(
        node,
        type,
      );
    }
    return false;
  }

  bool _addIdentifierRegion_function(SimpleIdentifier node) {
    final element = node.writeOrReadElement;
    if (element is! FunctionElement) {
      return false;
    }
    final parent = node.parent;
    final isInvocation =
        parent is MethodInvocation && parent.methodName == node;
    HighlightRegionType type;
    final isTopLevel = element.enclosingElement is CompilationUnitElement;
    if (node.inDeclarationContext()) {
      type = isTopLevel
          ? HighlightRegionType.TOP_LEVEL_FUNCTION_DECLARATION
          : HighlightRegionType.LOCAL_FUNCTION_DECLARATION;
    } else {
      type = isTopLevel
          ? isInvocation
              ? HighlightRegionType.TOP_LEVEL_FUNCTION_REFERENCE
              : HighlightRegionType.TOP_LEVEL_FUNCTION_TEAR_OFF
          : isInvocation
              ? HighlightRegionType.LOCAL_FUNCTION_REFERENCE
              : HighlightRegionType.LOCAL_FUNCTION_TEAR_OFF;
    }
    return _addRegion_node(node, type);
  }

  bool _addIdentifierRegion_getterSetterDeclaration(SimpleIdentifier node) {
    // should be declaration
    final parent = node.parent;
    if (!(parent is MethodDeclaration || parent is FunctionDeclaration)) {
      return false;
    }
    // should be property accessor
    final element = node.writeOrReadElement;
    if (element is! PropertyAccessorElement) {
      return false;
    }
    // getter or setter
    final isTopLevel = element.enclosingElement is CompilationUnitElement;
    HighlightRegionType type;
    if (element.isGetter) {
      if (isTopLevel) {
        type = HighlightRegionType.TOP_LEVEL_GETTER_DECLARATION;
      } else if (element.isStatic) {
        type = HighlightRegionType.STATIC_GETTER_DECLARATION;
      } else {
        type = HighlightRegionType.INSTANCE_GETTER_DECLARATION;
      }
    } else {
      if (isTopLevel) {
        type = HighlightRegionType.TOP_LEVEL_SETTER_DECLARATION;
      } else if (element.isStatic) {
        type = HighlightRegionType.STATIC_SETTER_DECLARATION;
      } else {
        type = HighlightRegionType.INSTANCE_SETTER_DECLARATION;
      }
    }
    return _addRegion_node(node, type);
  }

  bool _addIdentifierRegion_importPrefix(SimpleIdentifier node) {
    final element = node.writeOrReadElement;
    if (element is! PrefixElement) {
      return false;
    }
    return _addRegion_node(node, HighlightRegionType.IMPORT_PREFIX);
  }

  bool _addIdentifierRegion_keyword(SimpleIdentifier node) {
    final name = node.name;
    if (name == 'void') {
      return _addRegion_node(
        node,
        HighlightRegionType.KEYWORD,
      );
    }
    return false;
  }

  bool _addIdentifierRegion_label(SimpleIdentifier node) {
    final element = node.writeOrReadElement;
    if (element is! LabelElement) {
      return false;
    }
    return _addRegion_node(node, HighlightRegionType.LABEL);
  }

  bool _addIdentifierRegion_localVariable(SimpleIdentifier node) {
    final element = node.writeOrReadElement;
    if (element is! LocalVariableElement) {
      return false;
    }
    // OK
    final type = node.inDeclarationContext()
        ? HighlightRegionType.LOCAL_VARIABLE_DECLARATION
        : HighlightRegionType.LOCAL_VARIABLE_REFERENCE;
    return _addRegion_node(node, type);
  }

  bool _addIdentifierRegion_method(SimpleIdentifier node) {
    final element = node.writeOrReadElement;
    if (element is! MethodElement) {
      return false;
    }
    final isStatic = element.isStatic;
    final parent = node.parent;
    final isInvocation =
        parent is MethodInvocation && parent.methodName == node;
    // OK
    HighlightRegionType type;
    if (node.inDeclarationContext()) {
      if (isStatic) {
        type = HighlightRegionType.STATIC_METHOD_DECLARATION;
      } else {
        type = HighlightRegionType.INSTANCE_METHOD_DECLARATION;
      }
    } else {
      if (isStatic) {
        type = isInvocation
            ? HighlightRegionType.STATIC_METHOD_REFERENCE
            : HighlightRegionType.STATIC_METHOD_TEAR_OFF;
      } else {
        type = isInvocation
            ? HighlightRegionType.INSTANCE_METHOD_REFERENCE
            : HighlightRegionType.INSTANCE_METHOD_TEAR_OFF;
      }
    }
    return _addRegion_node(node, type);
  }

  bool _addIdentifierRegion_parameter(SimpleIdentifier node) {
    final element = node.writeOrReadElement;
    if (element is! ParameterElement) {
      return false;
    }
    final type = node.inDeclarationContext()
        ? HighlightRegionType.PARAMETER_DECLARATION
        : HighlightRegionType.PARAMETER_REFERENCE;
    return _addRegion_node(node, type);
  }

  bool _addIdentifierRegion_typeAlias(SimpleIdentifier node) {
    final element = node.writeOrReadElement;
    if (element is TypeAliasElement) {
      final type = element.aliasedType is FunctionType
          ? HighlightRegionType.FUNCTION_TYPE_ALIAS
          : HighlightRegionType.TYPE_ALIAS;
      return _addRegion_node(node, type);
    }
    return false;
  }

  bool _addIdentifierRegion_typeParameter(SimpleIdentifier node) {
    final element = node.writeOrReadElement;
    if (element is! TypeParameterElement) {
      return false;
    }
    return _addRegion_node(node, HighlightRegionType.TYPE_PARAMETER);
  }

  bool _addIdentifierRegion_unresolvedInstanceMemberReference(
    SimpleIdentifier node,
  ) {
    // unresolved
    final element = node.writeOrReadElement;
    if (element != null) {
      return false;
    }
    // invoke / get / set
    var decorate = false;
    final parent = node.parent;
    if (parent is MethodInvocation) {
      final target = parent.realTarget;
      if (parent.methodName == node &&
          target != null &&
          _isDynamicExpression(target)) {
        decorate = true;
      }
    } else if (node.inGetterContext() || node.inSetterContext()) {
      if (parent is PrefixedIdentifier) {
        decorate = parent.identifier == node;
      } else if (parent is PropertyAccess) {
        decorate = parent.propertyName == node;
      }
    }
    if (decorate) {
      _addRegion_node(
        node,
        HighlightRegionType.UNRESOLVED_INSTANCE_MEMBER_REFERENCE,
      );
      return true;
    }
    return false;
  }

  /// Adds a highlight region/semantic token for the given [offset]/[length].
  ///
  /// If the computer has a [range] set, tokens that fall outside of that range
  /// will not be recorded.
  void _addRegion(
    int offset,
    int length,
    HighlightRegionType type,
  ) {
    final range = this.range;
    if (range != null) {
      final end = offset + length;
      // Skip token if it ends before the range of starts after the range.
      if (end < range.offset || offset > range.end) {
        return;
      }
    }
    if (_computeRegions) {
      _regions.add(HighlightRegion(type, offset, length));
    }
  }

  bool _addRegion_node(
    AstNode node,
    HighlightRegionType type,
  ) {
    final offset = node.offset;
    final length = node.length;
    _addRegion(
      offset,
      length,
      type,
    );
    return true;
  }

  void _addRegion_nodeStart_tokenEnd(
    AstNode a,
    Token b,
    HighlightRegionType type,
  ) {
    final offset = a.offset;
    final end = b.end;
    _addRegion(offset, end - offset, type);
  }

  void _addRegion_token(
    Token? token,
    HighlightRegionType type,
  ) {
    if (token != null) {
      final offset = token.offset;
      final length = token.length;
      _addRegion(
        offset,
        length,
        type,
      );
    }
  }

  void _addRegion_tokenStart_tokenEnd(
    Token a,
    Token b,
    HighlightRegionType type,
  ) {
    final offset = a.offset;
    final end = b.end;
    _addRegion(offset, end - offset, type);
  }

  /// Checks whether [node] is the identifier part of an annotation.
  // ignore: unused_element
  bool _isAnnotationIdentifier(AstNode node) {
    if (node.parent is Annotation) {
      return true;
    } else if (node.parent is PrefixedIdentifier &&
        node.parent?.parent is Annotation) {
      return true;
    } else {
      return false;
    }
  }

  void _reset() {
    _computeRegions = false;
    _regions.clear();
  }

  static bool _isDynamicExpression(Expression e) {
    final type = e.staticType;
    return type != null && type.isDynamic;
  }
}

/// An AST visitor for [DartUnitHighlightsComputer].
class _DartUnitHighlightsComputerVisitor extends RecursiveAstVisitor<void> {
  _DartUnitHighlightsComputerVisitor(this.computer);
  final DartUnitHighlightsComputer computer;

  @override
  void visitAnnotation(Annotation node) {
    computer._addIdentifierRegion_annotation(node);
    super.visitAnnotation(node);
  }

  @override
  void visitAsExpression(AsExpression node) {
    computer._addRegion_token(node.asOperator, HighlightRegionType.BUILT_IN);
    super.visitAsExpression(node);
  }

  @override
  void visitAssertStatement(AssertStatement node) {
    computer._addRegion_token(
      node.assertKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitAssertStatement(node);
  }

  @override
  void visitAwaitExpression(AwaitExpression node) {
    computer._addRegion_token(
      node.awaitKeyword,
      HighlightRegionType.BUILT_IN,
    );
    super.visitAwaitExpression(node);
  }

  @override
  void visitBlockFunctionBody(BlockFunctionBody node) {
    _addRegions_functionBody(node);
    super.visitBlockFunctionBody(node);
  }

  @override
  void visitBooleanLiteral(BooleanLiteral node) {
    computer._addRegion_node(node, HighlightRegionType.KEYWORD);
    computer._addRegion_node(node, HighlightRegionType.LITERAL_BOOLEAN);
    super.visitBooleanLiteral(node);
  }

  @override
  void visitBreakStatement(BreakStatement node) {
    computer._addRegion_token(
      node.breakKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitBreakStatement(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    computer._addRegion_token(
      node.catchKeyword,
      HighlightRegionType.KEYWORD,
    );
    computer._addRegion_token(
      node.onKeyword,
      HighlightRegionType.BUILT_IN,
    );
    super.visitCatchClause(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    computer._addRegion_token(node.classKeyword, HighlightRegionType.KEYWORD);
    computer._addRegion_token(
      node.abstractKeyword,
      HighlightRegionType.BUILT_IN,
    );
    super.visitClassDeclaration(node);
  }

  @override
  void visitClassTypeAlias(ClassTypeAlias node) {
    computer._addRegion_token(
      node.abstractKeyword,
      HighlightRegionType.BUILT_IN,
    );
    super.visitClassTypeAlias(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    computer._addRegion_token(
      node.externalKeyword,
      HighlightRegionType.BUILT_IN,
    );
    computer._addRegion_token(
      node.factoryKeyword,
      HighlightRegionType.BUILT_IN,
    );
    computer._addRegion_token(node.constKeyword, HighlightRegionType.KEYWORD);
    super.visitConstructorDeclaration(node);
  }

  @override
  void visitConstructorReference(ConstructorReference node) {
    final constructorName = node.constructorName;
    constructorName.type.accept(this);

    // We have a `ConstructorReference` only when it is resolved.
    // TODO(scheglov) The `ConstructorName` in a tear-off always has a name,
    //  but this is not expressed via types.
    computer._addRegion_node(
      constructorName.name!,
      HighlightRegionType.CONSTRUCTOR_TEAR_OFF,
    );
  }

  @override
  void visitConstructorSelector(ConstructorSelector node) {
    computer._addRegion_node(
      node.name,
      HighlightRegionType.CONSTRUCTOR,
    );
    node.visitChildren(this);
  }

  @override
  void visitContinueStatement(ContinueStatement node) {
    computer._addRegion_token(
      node.continueKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitContinueStatement(node);
  }

  @override
  void visitDeclaredIdentifier(DeclaredIdentifier node) {
    computer._addRegion_token(node.keyword, HighlightRegionType.KEYWORD);
    super.visitDeclaredIdentifier(node);
  }

  @override
  void visitDefaultFormalParameter(DefaultFormalParameter node) {
    computer._addRegion_token(
      node.requiredKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitDefaultFormalParameter(node);
  }

  @override
  void visitDoStatement(DoStatement node) {
    computer._addRegion_token(
      node.doKeyword,
      HighlightRegionType.KEYWORD,
    );
    computer._addRegion_token(
      node.whileKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitDoStatement(node);
  }

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    computer._addRegion_node(node, HighlightRegionType.LITERAL_DOUBLE);
    super.visitDoubleLiteral(node);
  }

  @override
  void visitEnumConstantDeclaration(EnumConstantDeclaration node) {
    computer._addRegion_node(
      node.name,
      HighlightRegionType.ENUM_CONSTANT,
    );
    node.visitChildren(this);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    computer._addRegion_token(node.enumKeyword, HighlightRegionType.KEYWORD);
    super.visitEnumDeclaration(node);
  }

  @override
  void visitExportDirective(ExportDirective node) {
    computer._addRegion_node(node, HighlightRegionType.DIRECTIVE);
    computer._addRegion_token(node.keyword, HighlightRegionType.BUILT_IN);
    _addRegions_configurations(node.configurations);
    super.visitExportDirective(node);
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    _addRegions_functionBody(node);
    super.visitExpressionFunctionBody(node);
  }

  @override
  void visitExtendsClause(ExtendsClause node) {
    computer._addRegion_token(node.extendsKeyword, HighlightRegionType.KEYWORD);
    super.visitExtendsClause(node);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    computer._addRegion_token(
      node.extensionKeyword,
      HighlightRegionType.KEYWORD,
    );
    computer._addRegion_token(node.onKeyword, HighlightRegionType.BUILT_IN);
    super.visitExtensionDeclaration(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    computer._addRegion_token(
      node.abstractKeyword,
      HighlightRegionType.BUILT_IN,
    );
    computer._addRegion_token(
      node.externalKeyword,
      HighlightRegionType.BUILT_IN,
    );
    computer._addRegion_token(node.staticKeyword, HighlightRegionType.BUILT_IN);
    super.visitFieldDeclaration(node);
  }

  @override
  void visitFieldFormalParameter(FieldFormalParameter node) {
    computer._addRegion_token(
      node.requiredKeyword,
      HighlightRegionType.KEYWORD,
    );

    final element = node.declaredElement;
    if (element is FieldFormalParameterElement) {
      final field = element.field;
      if (field != null) {
        computer._addRegion_node(
          node.identifier,
          HighlightRegionType.INSTANCE_FIELD_REFERENCE,
        );
      }
    }

    super.visitFieldFormalParameter(node);
  }

  @override
  void visitForEachPartsWithDeclaration(ForEachPartsWithDeclaration node) {
    computer._addRegion_token(
      node.inKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitForEachPartsWithDeclaration(node);
  }

  @override
  void visitForEachPartsWithIdentifier(ForEachPartsWithIdentifier node) {
    computer._addRegion_token(
      node.inKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitForEachPartsWithIdentifier(node);
  }

  @override
  void visitForElement(ForElement node) {
    computer._addRegion_token(
      node.awaitKeyword,
      HighlightRegionType.BUILT_IN,
    );
    computer._addRegion_token(
      node.forKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitForElement(node);
  }

  @override
  void visitForStatement(ForStatement node) {
    computer._addRegion_token(
      node.awaitKeyword,
      HighlightRegionType.BUILT_IN,
    );
    computer._addRegion_token(
      node.forKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitForStatement(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    computer._addRegion_token(
      node.externalKeyword,
      HighlightRegionType.BUILT_IN,
    );
    computer._addRegion_token(
      node.propertyKeyword,
      HighlightRegionType.BUILT_IN,
    );
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitFunctionTypeAlias(FunctionTypeAlias node) {
    computer._addRegion_token(
      node.typedefKeyword,
      HighlightRegionType.BUILT_IN,
    );
    super.visitFunctionTypeAlias(node);
  }

  @override
  void visitFunctionTypedFormalParameter(FunctionTypedFormalParameter node) {
    computer._addRegion_token(
      node.requiredKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitFunctionTypedFormalParameter(node);
  }

  @override
  void visitGenericFunctionType(GenericFunctionType node) {
    computer._addRegion_token(
      node.functionKeyword,
      HighlightRegionType.BUILT_IN,
    );
    super.visitGenericFunctionType(node);
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    computer._addRegion_token(
      node.typedefKeyword,
      HighlightRegionType.BUILT_IN,
    );
    super.visitGenericTypeAlias(node);
  }

  @override
  void visitHideCombinator(HideCombinator node) {
    computer._addRegion_token(node.keyword, HighlightRegionType.BUILT_IN);
    super.visitHideCombinator(node);
  }

  @override
  void visitIfElement(IfElement node) {
    computer._addRegion_token(
      node.ifKeyword,
      HighlightRegionType.KEYWORD,
    );
    computer._addRegion_token(
      node.elseKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitIfElement(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    computer._addRegion_token(
      node.ifKeyword,
      HighlightRegionType.KEYWORD,
    );
    computer._addRegion_token(
      node.elseKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitIfStatement(node);
  }

  @override
  void visitImplementsClause(ImplementsClause node) {
    computer._addRegion_token(
      node.implementsKeyword,
      HighlightRegionType.BUILT_IN,
    );
    super.visitImplementsClause(node);
  }

  @override
  void visitImportDirective(ImportDirective node) {
    computer._addRegion_node(node, HighlightRegionType.DIRECTIVE);
    computer._addRegion_token(node.keyword, HighlightRegionType.BUILT_IN);
    computer._addRegion_token(
      node.deferredKeyword,
      HighlightRegionType.BUILT_IN,
    );
    computer._addRegion_token(node.asKeyword, HighlightRegionType.BUILT_IN);
    _addRegions_configurations(node.configurations);
    super.visitImportDirective(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.keyword != null) {
      computer._addRegion_token(node.keyword, HighlightRegionType.KEYWORD);
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    computer._addRegion_node(node, HighlightRegionType.LITERAL_INTEGER);
    super.visitIntegerLiteral(node);
  }

  @override
  void visitInterpolationExpression(InterpolationExpression node) {
    super.visitInterpolationExpression(node);
  }

  @override
  void visitInterpolationString(InterpolationString node) {
    computer._addRegion_node(node, HighlightRegionType.LITERAL_STRING);
    super.visitInterpolationString(node);
  }

  @override
  void visitIsExpression(IsExpression node) {
    computer._addRegion_token(node.isOperator, HighlightRegionType.KEYWORD);
    super.visitIsExpression(node);
  }

  @override
  void visitLibraryDirective(LibraryDirective node) {
    computer._addRegion_node(node, HighlightRegionType.DIRECTIVE);
    computer._addRegion_token(node.keyword, HighlightRegionType.BUILT_IN);
    super.visitLibraryDirective(node);
  }

  @override
  void visitLibraryIdentifier(LibraryIdentifier node) {
    computer._addRegion_node(node, HighlightRegionType.LIBRARY_NAME);
  }

  @override
  void visitListLiteral(ListLiteral node) {
    computer._addRegion_node(node, HighlightRegionType.LITERAL_LIST);
    computer._addRegion_token(node.constKeyword, HighlightRegionType.KEYWORD);
    super.visitListLiteral(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    computer._addRegion_token(
      node.externalKeyword,
      HighlightRegionType.BUILT_IN,
    );
    computer._addRegion_token(
      node.modifierKeyword,
      HighlightRegionType.BUILT_IN,
    );
    computer._addRegion_token(
      node.operatorKeyword,
      HighlightRegionType.BUILT_IN,
    );
    computer._addRegion_token(
      node.propertyKeyword,
      HighlightRegionType.BUILT_IN,
    );
    super.visitMethodDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    computer._addRegion_token(node.mixinKeyword, HighlightRegionType.BUILT_IN);
    super.visitMixinDeclaration(node);
  }

  @override
  void visitNamedType(NamedType node) {
    final type = node.type;
    if (type != null) {
      if (type.isDynamic && node.name.name == 'dynamic') {
        computer._addRegion_node(node, HighlightRegionType.TYPE_NAME_DYNAMIC);
        return;
      }
    }
    super.visitNamedType(node);
  }

  @override
  void visitNativeClause(NativeClause node) {
    computer._addRegion_token(node.nativeKeyword, HighlightRegionType.BUILT_IN);
    super.visitNativeClause(node);
  }

  @override
  void visitNativeFunctionBody(NativeFunctionBody node) {
    computer._addRegion_token(node.nativeKeyword, HighlightRegionType.BUILT_IN);
    super.visitNativeFunctionBody(node);
  }

  @override
  void visitNullLiteral(NullLiteral node) {
    computer._addRegion_token(node.literal, HighlightRegionType.KEYWORD);
    super.visitNullLiteral(node);
  }

  @override
  void visitOnClause(OnClause node) {
    computer._addRegion_token(node.onKeyword, HighlightRegionType.BUILT_IN);
    super.visitOnClause(node);
  }

  @override
  void visitPartDirective(PartDirective node) {
    computer._addRegion_node(node, HighlightRegionType.DIRECTIVE);
    computer._addRegion_token(node.keyword, HighlightRegionType.BUILT_IN);
    super.visitPartDirective(node);
  }

  @override
  void visitPartOfDirective(PartOfDirective node) {
    computer._addRegion_node(node, HighlightRegionType.DIRECTIVE);
    computer._addRegion_tokenStart_tokenEnd(
      node.partKeyword,
      node.ofKeyword,
      HighlightRegionType.BUILT_IN,
    );
    super.visitPartOfDirective(node);
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    computer._addRegion_token(
      node.rethrowKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitRethrowExpression(node);
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    computer._addRegion_token(
      node.returnKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitReturnStatement(node);
  }

  @override
  void visitSetOrMapLiteral(SetOrMapLiteral node) {
    if (node.isMap) {
      computer._addRegion_node(node, HighlightRegionType.LITERAL_MAP);
      // TODO(brianwilkerson) Add a highlight region for set literals. This
      //  would be a breaking change, but would be consistent with list and map
      //  literals.
//    } else if (node.isSet) {
//    computer._addRegion_node(node, HighlightRegionType.LITERAL_SET);
    }
    computer._addRegion_token(node.constKeyword, HighlightRegionType.KEYWORD);
    super.visitSetOrMapLiteral(node);
  }

  @override
  void visitShowCombinator(ShowCombinator node) {
    computer._addRegion_token(node.keyword, HighlightRegionType.BUILT_IN);
    super.visitShowCombinator(node);
  }

  @override
  void visitSimpleFormalParameter(SimpleFormalParameter node) {
    computer._addRegion_token(
      node.requiredKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitSimpleFormalParameter(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    computer._addIdentifierRegion(node);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    computer._addRegion_node(node, HighlightRegionType.LITERAL_STRING);
    _addRegions_stringEscapes(node);
    super.visitSimpleStringLiteral(node);
  }

  @override
  void visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    computer._addRegion_token(node.superKeyword, HighlightRegionType.KEYWORD);
    super.visitSuperConstructorInvocation(node);
  }

  @override
  void visitSuperFormalParameter(SuperFormalParameter node) {
    computer._addRegion_token(
      node.superKeyword,
      HighlightRegionType.KEYWORD,
    );

    computer._addRegion_node(
      node.identifier,
      HighlightRegionType.PARAMETER_DECLARATION,
    );

    node.type?.accept(this);
    node.typeParameters?.accept(this);
    node.parameters?.accept(this);
  }

  @override
  void visitSwitchCase(SwitchCase node) {
    computer._addRegion_token(
      node.keyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitSwitchCase(node);
  }

  @override
  void visitSwitchDefault(SwitchDefault node) {
    computer._addRegion_token(
      node.keyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitSwitchDefault(node);
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    computer._addRegion_token(
      node.switchKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitSwitchStatement(node);
  }

  @override
  void visitThisExpression(ThisExpression node) {
    computer._addRegion_token(node.thisKeyword, HighlightRegionType.KEYWORD);
    super.visitThisExpression(node);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    computer._addRegion_token(
      node.throwKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitThrowExpression(node);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    computer._addRegion_token(
      node.externalKeyword,
      HighlightRegionType.BUILT_IN,
    );
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitTryStatement(TryStatement node) {
    computer._addRegion_token(
      node.tryKeyword,
      HighlightRegionType.KEYWORD,
    );
    computer._addRegion_token(
      node.finallyKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitTryStatement(node);
  }

  @override
  void visitVariableDeclarationList(VariableDeclarationList node) {
    computer._addRegion_token(node.lateKeyword, HighlightRegionType.KEYWORD);
    computer._addRegion_token(node.keyword, HighlightRegionType.KEYWORD);
    super.visitVariableDeclarationList(node);
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    computer._addRegion_token(
      node.whileKeyword,
      HighlightRegionType.KEYWORD,
    );
    super.visitWhileStatement(node);
  }

  @override
  void visitWithClause(WithClause node) {
    computer._addRegion_token(node.withKeyword, HighlightRegionType.KEYWORD);
    super.visitWithClause(node);
  }

  @override
  void visitYieldStatement(YieldStatement node) {
    final keyword = node.yieldKeyword;
    final star = node.star;
    final offset = keyword.offset;
    final end = star != null ? star.end : keyword.end;
    computer._addRegion(
      offset,
      end - offset,
      HighlightRegionType.BUILT_IN,
    );
    super.visitYieldStatement(node);
  }

  void _addRegions_configurations(List<Configuration> configurations) {
    for (final configuration in configurations) {
      computer._addRegion_token(
        configuration.ifKeyword,
        HighlightRegionType.BUILT_IN,
      );
    }
  }

  void _addRegions_functionBody(FunctionBody node) {
    final keyword = node.keyword;
    if (keyword != null) {
      final star = node.star;
      final offset = keyword.offset;
      final end = star != null ? star.end : keyword.end;
      computer._addRegion(
        offset,
        end - offset,
        HighlightRegionType.BUILT_IN,
      );
    }
  }

  void _addRegions_stringEscapes(SimpleStringLiteral node) {
    final string = node.literal.lexeme;
    final quote = analyzeQuote(string);
    final startIndex = firstQuoteLength(string, quote);
    final endIndex = string.length - lastQuoteLength(quote);
    switch (quote) {
      case Quote.Single:
      case Quote.Double:
      case Quote.MultiLineSingle:
      case Quote.MultiLineDouble:
        _findEscapes(
          node,
          startIndex: startIndex,
          endIndex: endIndex,
          listener: (offset, end) {
            final length = end - offset;
            computer._addRegion(
              node.offset + offset,
              length,
              HighlightRegionType.VALID_STRING_ESCAPE,
            );
          },
        );
        break;
      case Quote.RawSingle:
      case Quote.RawDouble:
      case Quote.RawMultiLineSingle:
      case Quote.RawMultiLineDouble:
        // Raw strings don't have escape characters.
        break;
    }
  }

  /// Finds escaped regions within a string between [startIndex] and [endIndex],
  /// calling [listener] for each found region.
  void _findEscapes(
    SimpleStringLiteral node, {
    required int startIndex,
    required int endIndex,
    required void Function(int offset, int end) listener,
  }) {
    final string = node.literal.lexeme;
    final codeUnits = string.codeUnits;
    final length = string.length;

    bool isBackslash(int i) => i <= length && codeUnits[i] == char.$BACKSLASH;
    bool isHexEscape(int i) => i <= length && codeUnits[i] == char.$x;
    bool isUnicodeHexEscape(int i) => i <= length && codeUnits[i] == char.$u;
    bool isOpenBrace(int i) =>
        i <= length && codeUnits[i] == char.$OPEN_CURLY_BRACKET;
    bool isCloseBrace(int i) =>
        i <= length && codeUnits[i] == char.$CLOSE_CURLY_BRACKET;
    int? numHexDigits(int i, {required int min, required int max}) {
      var numHexDigits = 0;
      for (var j = i; j < math.min(i + max, length); j++) {
        if (!char.isHexDigit(codeUnits[j])) {
          break;
        }
        numHexDigits++;
      }
      return numHexDigits >= min ? numHexDigits : null;
    }

    for (var i = startIndex; i < endIndex;) {
      if (isBackslash(i)) {
        final backslashOffset = i++;
        // All escaped characters are a single character except for:
        // `\uXXXX` or `\u{XX?X?X?X?X?}` for Unicode hex escape.
        // `\xXX` for hex escape.
        if (isHexEscape(i)) {
          // Expect exactly 2 hex digits.
          final numDigits = numHexDigits(i + 1, min: 2, max: 2);
          if (numDigits != null) {
            i += 1 + numDigits;
            listener(backslashOffset, i);
          }
        } else if (isUnicodeHexEscape(i) && isOpenBrace(i + 1)) {
          // Expect 1-6 hex digits followed by '}'.
          final numDigits = numHexDigits(i + 2, min: 1, max: 6);
          if (numDigits != null && isCloseBrace(i + 2 + numDigits)) {
            i += 2 + numDigits + 1;
            listener(backslashOffset, i);
          }
        } else if (isUnicodeHexEscape(i)) {
          // Expect exactly 4 hex digits.
          final numDigits = numHexDigits(i + 1, min: 4, max: 4);
          if (numDigits != null) {
            i += 1 + numDigits;
            listener(backslashOffset, i);
          }
        } else {
          i++;
          // Single-character escape.
          listener(backslashOffset, i);
        }
      } else {
        i++;
      }
    }
  }
}