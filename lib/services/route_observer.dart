import 'package:flutter/material.dart';

/// Observador global de rotas — usado por telas de lista para recarregar os
/// dados sempre que voltam a ficar visíveis (ex.: após fechar uma tela de
/// criação/edição), sem depender de encadear `.then()` em cada
/// `Navigator.push`, o que é frágil quando a tela filha usa
/// `pushReplacement`/`popUntil`.
final RouteObserver<PageRoute> appRouteObserver = RouteObserver<PageRoute>();
