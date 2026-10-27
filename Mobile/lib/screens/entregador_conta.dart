part of 'entregador_screen.dart';

// Abas Ganhos e Perfil do entregador.

const _amarelo = Color(0xFFF5A524);
const _diasSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

String _dataHora(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} · '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String _nota(double n) => n.toStringAsFixed(1).replaceAll('.', ',');

/// Cinco estrelas, com meia estrela quando a média pede.
class _Estrelas extends StatelessWidget {
  const _Estrelas({required this.nota, this.tamanho = 16});

  final double nota;
  final double tamanho;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              nota >= i
                  ? Icons.star_rounded
                  : nota >= i - 0.5
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded,
              size: tamanho,
              color: _amarelo,
            ),
        ],
      );
}

// ---------------------------------------------------------------------------
// Ganhos

class _GanhosEntregador extends StatefulWidget {
  const _GanhosEntregador({required this.ativo});

  /// A aba recarrega sempre que volta a ficar visível (pode ter entregado algo nesse meio tempo).
  final bool ativo;

  @override
  State<_GanhosEntregador> createState() => _GanhosEntregadorState();
}

class _GanhosEntregadorState extends State<_GanhosEntregador> {
  Map<String, dynamic>? _g;
  String? _erro;
  var _periodo = 'Hoje';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void didUpdateWidget(covariant _GanhosEntregador oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ativo && !oldWidget.ativo) _carregar();
  }

  Future<void> _carregar() async {
    try {
      final g = await Api.instance.get<Map<String, dynamic>>('/api/entregador/ganhos');
      if (mounted) {
        setState(() {
          _g = g;
          _erro = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    return Scaffold(
      appBar: AppBar(title: const Text('Ganhos')),
      body: g == null
          ? Center(child: _erro == null ? const TomateCarregando() : Text(_erro!))
          : RefreshIndicator(
              color: XepaCores.tomate,
              onRefresh: _carregar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final p in const ['Hoje', 'Semana', 'Mês', 'Total'])
                        ChoiceChip(label: Text(p), selected: _periodo == p, onSelected: (_) => setState(() => _periodo = p)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ResumoGanhos(g: g, periodo: _periodo),
                  const _Titulo('Últimos 7 dias'),
                  _GraficoDias(dias: (g['ultimosDias'] as List).cast<Map<String, dynamic>>()),
                  const _Titulo('Corridas feitas'),
                  if ((g['corridas'] as List).isEmpty)
                    const EstadoVazio(
                      titulo: 'Nenhuma entrega ainda',
                      texto: 'Fique online, aceite uma corrida e o valor aparece aqui assim que você entregar.',
                    )
                  else
                    for (final c in (g['corridas'] as List).cast<Map<String, dynamic>>()) _LinhaCorridaFeita(c: c),
                  const SizedBox(height: 14),
                  const Text(
                    'A taxa de entrega que o cliente paga é 100% sua. Os valores contam as corridas finalizadas com o código do cliente.',
                    style: TextStyle(color: XepaCores.textoSecundario, fontSize: 12.5),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ResumoGanhos extends StatelessWidget {
  const _ResumoGanhos({required this.g, required this.periodo});

  final Map<String, dynamic> g;
  final String periodo;

  @override
  Widget build(BuildContext context) {
    final (sufixo, rotulo) = switch (periodo) {
      'Semana' => ('Semana', 'Ganhos da semana'),
      'Mês' => ('Mes', 'Ganhos do mês'),
      'Total' => ('Total', 'Ganhos desde o começo'),
      _ => ('Hoje', 'Ganhos de hoje'),
    };
    final valor = (g['ganhos$sufixo'] as num).toDouble();
    final corridas = g['corridas$sufixo'] as int;
    final km = (g['km$sufixo'] as num?)?.toDouble();
    final media = corridas == 0 ? 0.0 : valor / corridas;
    return ClipRRect(
      borderRadius: BorderRadius.circular(XepaRaios.cartao),
      child: Container(
        color: XepaCores.texto,
        child: Stack(
          children: [
            const Positioned(
              right: -24,
              bottom: -30,
              child: TomateMarcaDagua(tamanho: 130, opacidade: 0.12, angulo: -0.3, cor: Colors.white),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rotulo, style: TextStyle(color: Colors.white.withAlpha(190), fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(formatarPreco(valor),
                      style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Numero(valor: '$corridas', rotulo: corridas == 1 ? 'corrida' : 'corridas'),
                      if (km != null) _Numero(valor: _km(km), rotulo: 'de entrega'),
                      _Numero(valor: formatarPreco(media), rotulo: 'por corrida'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({required this.valor, required this.rotulo});

  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            Text(rotulo, style: TextStyle(color: Colors.white.withAlpha(170), fontSize: 12)),
          ],
        ),
      );
}

/// Barras dos últimos 7 dias; hoje em vermelho-tomate.
class _GraficoDias extends StatelessWidget {
  const _GraficoDias({required this.dias});

  final List<Map<String, dynamic>> dias;

  @override
  Widget build(BuildContext context) {
    final valores = dias.map((d) => (d['valor'] as num).toDouble()).toList();
    final maximo = valores.fold<double>(0, (a, b) => b > a ? b : a);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(XepaRaios.cartao),
        border: Border.all(color: XepaCores.borda),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < dias.length; i++)
            Expanded(
              child: Column(
                children: [
                  Text(
                    valores[i] == 0 ? '' : formatarPreco(valores[i]).replaceAll('R\$ ', ''),
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: maximo == 0 ? 4 : 4 + 106 * valores[i] / maximo,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: i == dias.length - 1 ? XepaCores.tomate : XepaCores.verdeFolha.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    i == dias.length - 1 ? 'Hoje' : _diasSemana[DateTime.parse(dias[i]['dia'] as String).weekday - 1],
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: i == dias.length - 1 ? FontWeight.w800 : FontWeight.w600,
                      color: i == dias.length - 1 ? XepaCores.tomateEscuro : XepaCores.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LinhaCorridaFeita extends StatelessWidget {
  const _LinhaCorridaFeita({required this.c});

  final Map<String, dynamic> c;

  @override
  Widget build(BuildContext context) {
    final em = DateTime.parse(c['entregueEm'] as String).toLocal();
    final nota = c['nota'] as int?;
    final comentario = c['comentario'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(XepaRaios.cartao),
        border: Border.all(color: XepaCores.borda),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: XepaCores.verdeClaro, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: XepaCores.verde, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c['loja']} → ${c['bairro']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${_dataHora(em)} · ${_km((c['km'] as num).toDouble())} · #${c['pedidoId']}',
                    style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12.5)),
                if (nota != null) ...[
                  const SizedBox(height: 4),
                  _Estrelas(nota: nota.toDouble(), tamanho: 15),
                ],
                if (comentario != null)
                  Text('“$comentario”', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12.5)),
              ],
            ),
          ),
          Text(formatarPreco((c['valor'] as num).toDouble()),
              style: const TextStyle(fontWeight: FontWeight.w800, color: XepaCores.verde, fontSize: 16)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Perfil

class _PerfilEntregador extends StatefulWidget {
  const _PerfilEntregador({required this.ativo});

  final bool ativo;

  @override
  State<_PerfilEntregador> createState() => _PerfilEntregadorState();
}

class _PerfilEntregadorState extends State<_PerfilEntregador> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _telefone = TextEditingController();
  final _placa = TextEditingController();
  final _modelo = TextEditingController();
  double _raio = 8;
  Map<String, dynamic>? _p;
  String? _erro;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void didUpdateWidget(covariant _PerfilEntregador oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ativo && !oldWidget.ativo) _carregar();
  }

  @override
  void dispose() {
    for (final c in [_nome, _telefone, _placa, _modelo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      _preencher(await Api.instance.get<Map<String, dynamic>>('/api/entregador/perfil'));
    } on ApiException catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    }
  }

  void _preencher(Map<String, dynamic> p) {
    if (!mounted) return;
    setState(() {
      _p = p;
      _erro = null;
      _nome.text = p['nome'] as String;
      _telefone.text = p['telefone'] as String? ?? '';
      _placa.text = p['placa'] as String? ?? '';
      _modelo.text = p['modeloMoto'] as String? ?? '';
      _raio = (p['raioCorridasKm'] as int).toDouble();
    });
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final p = await Api.instance.put<Map<String, dynamic>>('/api/entregador/perfil', {
        'nome': _nome.text.trim(),
        'telefone': _telefone.text.trim(),
        'placa': _placa.text.trim(),
        'modeloMoto': _modelo.text.trim(),
        'raioCorridasKm': _raio.round(),
      });
      await AuthService.instance.restaurarSessao();
      _preencher(p);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil atualizado.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _sair() async {
    // Quem sai do app para de receber corridas.
    try {
      await Api.instance.put<Map<String, dynamic>>('/api/entregador/online', {'online': false});
    } on ApiException {
      // Sai mesmo assim.
    }
    await AuthService.instance.sair();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: p == null
          ? Center(child: _erro == null ? const TomateCarregando() : Text(_erro!))
          : RefreshIndicator(
              color: XepaCores.tomate,
              onRefresh: _carregar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  _CabecalhoPerfil(p: p),
                  const SizedBox(height: 14),
                  _CartaoReputacao(p: p),
                  if ((p['ultimasAvaliacoes'] as List).isNotEmpty) ...[
                    const _Titulo('O que os clientes dizem'),
                    for (final a in (p['ultimasAvaliacoes'] as List).cast<Map<String, dynamic>>()) _LinhaAvaliacao(a: a),
                  ],
                  const _Titulo('Seus dados e a moto'),
                  Form(
                    key: _form,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nome,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outline_rounded)),
                          validator: (v) => (v == null || v.trim().length < 3) ? 'Informe seu nome.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _telefone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Telefone', prefixIcon: Icon(Icons.phone_outlined)),
                          validator: (v) => (v == null || v.replaceAll(RegExp(r'\D'), '').length < 10) ? 'Telefone com DDD.' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _placa,
                                textCapitalization: TextCapitalization.characters,
                                maxLength: 8,
                                decoration: const InputDecoration(
                                    labelText: 'Placa', counterText: '', prefixIcon: Icon(Icons.pin_outlined)),
                                validator: (v) => RegExp(r'^[A-Za-z]{3}-?\d[A-Za-z\d]\d{2}$').hasMatch(v?.trim() ?? '')
                                    ? null
                                    : 'Ex.: ABC1D23',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _modelo,
                                maxLength: 60,
                                decoration: const InputDecoration(
                                    labelText: 'Moto', hintText: 'Honda CG 160', counterText: '', prefixIcon: Icon(Icons.two_wheeler_rounded)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(XepaRaios.campo),
                            border: Border.all(color: XepaCores.borda),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Corridas até ${_raio.round()} km de mim',
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                              const Text('Distância máxima até a loja de coleta para a corrida aparecer.',
                                  style: TextStyle(color: XepaCores.textoSecundario, fontSize: 12.5)),
                              Slider(
                                value: _raio,
                                min: 1,
                                max: 15,
                                divisions: 14,
                                label: '${_raio.round()} km',
                                activeColor: XepaCores.tomate,
                                onChanged: (v) => setState(() => _raio = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _salvando ? null : _salvar,
                            child: _salvando
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Salvar alterações'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _PedirComida(onTap: () => trocarModoEntregador(context, cliente: true)),
                  const _Titulo('Conta'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(XepaRaios.cartao),
                      border: Border.all(color: XepaCores.borda),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.lock_outline_rounded),
                          title: const Text('Alterar senha', style: TextStyle(fontWeight: FontWeight.w700)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlterarSenhaScreen())),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.help_outline_rounded),
                          title: const Text('Ajuda', style: TextStyle(fontWeight: FontWeight.w700)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AjudaScreen())),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.logout_rounded, color: XepaCores.tomateEscuro),
                          title: const Text('Sair', style: TextStyle(fontWeight: FontWeight.w700, color: XepaCores.tomateEscuro)),
                          onTap: _sair,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Center(child: XepaMarca(tamanho: 18)),
                ],
              ),
            ),
    );
  }
}

class _CabecalhoPerfil extends StatelessWidget {
  const _CabecalhoPerfil({required this.p});

  final Map<String, dynamic> p;

  @override
  Widget build(BuildContext context) {
    final nome = p['nome'] as String;
    final partes = nome.trim().split(RegExp(r'\s+'));
    final iniciais = (partes.first[0] + (partes.length > 1 ? partes.last[0] : '')).toUpperCase();
    final desde = DateTime.parse(p['membroDesde'] as String).toLocal();
    const meses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
    final placa = p['placa'] as String?;
    final moto = p['modeloMoto'] as String?;
    return Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: XepaCores.tomate,
          child: Text(iniciais, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nome, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              Text('Entregador parceiro desde ${meses[desde.month - 1]}/${desde.year}',
                  style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (placa != null) _Etiqueta(texto: placa, cor: XepaCores.texto),
                  if (moto != null) _Etiqueta(texto: moto, cor: XepaCores.paoEscuro),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Nota média dada pelos clientes, distribuição das estrelas e total de corridas.
class _CartaoReputacao extends StatelessWidget {
  const _CartaoReputacao({required this.p});

  final Map<String, dynamic> p;

  @override
  Widget build(BuildContext context) {
    final nota = (p['nota'] as num?)?.toDouble();
    final avaliacoes = p['avaliacoes'] as int;
    final estrelas = (p['estrelas'] as List).cast<int>();
    final corridas = p['corridasTotal'] as int;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(XepaRaios.cartao),
        border: Border.all(color: XepaCores.borda),
        boxShadow: sombraCartao,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sua nota', style: TextStyle(color: XepaCores.textoSecundario, fontWeight: FontWeight.w700, fontSize: 12.5)),
                Text(nota == null ? '—' : _nota(nota),
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.1)),
                _Estrelas(nota: nota ?? 0),
                const SizedBox(height: 4),
                Text(
                  avaliacoes == 0 ? 'Sem avaliações' : '$avaliacoes ${avaliacoes == 1 ? 'avaliação' : 'avaliações'}',
                  style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text('$corridas ${corridas == 1 ? 'entrega' : 'entregas'}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: avaliacoes == 0
                ? const Padding(
                    padding: EdgeInsets.only(top: 18),
                    child: Text(
                      'Depois de cada entrega o cliente pode te dar de 1 a 5 estrelas. Sua nota aparece aqui.',
                      style: TextStyle(color: XepaCores.textoSecundario, fontSize: 13),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < 5; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.5),
                          child: Row(
                            children: [
                              SizedBox(width: 12, child: Text('${5 - i}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                              const Icon(Icons.star_rounded, size: 13, color: _amarelo),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: estrelas[i] / avaliacoes,
                                    minHeight: 7,
                                    color: _amarelo,
                                    backgroundColor: XepaCores.bege,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 22,
                                child: Text('${estrelas[i]}',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 12, color: XepaCores.textoSecundario)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _LinhaAvaliacao extends StatelessWidget {
  const _LinhaAvaliacao({required this.a});

  final Map<String, dynamic> a;

  @override
  Widget build(BuildContext context) {
    final em = DateTime.parse(a['em'] as String).toLocal();
    final comentario = a['comentario'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(XepaRaios.cartao),
        border: Border.all(color: XepaCores.borda),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Estrelas(nota: (a['nota'] as int).toDouble(), tamanho: 15),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${a['cliente']} · ${_dataHora(em)}',
                    style: const TextStyle(color: XepaCores.textoSecundario, fontSize: 12.5)),
              ),
            ],
          ),
          if (comentario != null) ...[
            const SizedBox(height: 6),
            Text(comentario),
          ],
        ],
      ),
    );
  }
}

/// Atalho para o modo cliente: a mesma conta pede comida e acompanha o pedido como qualquer cliente.
class _PedirComida extends StatelessWidget {
  const _PedirComida({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: XepaCores.tomateClaro,
        borderRadius: BorderRadius.circular(XepaRaios.cartao),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(XepaRaios.cartao),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.restaurant_rounded, color: XepaCores.tomateEscuro, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pedir comida', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('Use a mesma conta como cliente. Você fica offline até voltar a entregar.',
                          style: TextStyle(color: XepaCores.textoSecundario, fontSize: 12.5)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: XepaCores.tomateEscuro),
              ],
            ),
          ),
        ),
      );
}
