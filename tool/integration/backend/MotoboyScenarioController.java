package br.com.nhac.backend_nhac.config;

import br.com.nhac.backend_nhac.domain.auth.*;
import br.com.nhac.backend_nhac.domain.entrega.*;
import br.com.nhac.backend_nhac.domain.entregador.*;
import br.com.nhac.backend_nhac.domain.loja.*;
import br.com.nhac.backend_nhac.domain.pedido.*;
import br.com.nhac.backend_nhac.domain.usuario.*;
import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

/** Controle de fixtures: compilado só no runner, ADMIN e H2 loopback obrigatórios. */
@RestController
@Profile("motoboy-integration")
@RequestMapping("/api/v1/suporte/motoboy-it")
@PreAuthorize("hasRole('ADMIN')")
public class MotoboyScenarioController {
    private final MotoboyIntegrationFixture fixture;
    private final UsuarioRepository usuarios;
    private final EntregadorRepository entregadores;
    private final LojaRepository lojas;
    private final PedidoRepository pedidos;
    private final OfertaEntregaRepository ofertas;
    private final CodigoVerificacaoEmailRepository emails;
    private final CodigoVerificacaoRepository sms;
    private final AtomicInteger sequence = new AtomicInteger(100);

    public MotoboyScenarioController(MotoboyIntegrationFixture fixture,
            UsuarioRepository usuarios, EntregadorRepository entregadores, LojaRepository lojas,
            PedidoRepository pedidos, OfertaEntregaRepository ofertas,
            CodigoVerificacaoEmailRepository emails, CodigoVerificacaoRepository sms, Environment env) {
        if (!"127.0.0.1".equals(env.getProperty("server.address")) ||
                !env.getProperty("spring.datasource.url", "").startsWith("jdbc:h2:mem:")) {
            throw new IllegalStateException("Fixtures de integração exigem H2 em memória e loopback.");
        }
        this.fixture = fixture; this.usuarios = usuarios; this.entregadores = entregadores;
        this.lojas = lojas; this.pedidos = pedidos; this.ofertas = ofertas;
        this.emails = emails; this.sms = sms;
    }

    @PostMapping("/cenarios/{id}")
    @Transactional
    public Map<String,Object> criar(@PathVariable String id) {
        if (!id.matches("[a-z0-9-]{1,24}") || usuarios.existsById("it-" + id + "-a"))
            throw new IllegalArgumentException("Cenário deve ser novo e identificado por até 24 caracteres.");
        var a = fixture.usuario(id + "-a", Papel.CLIENTE);
        var b = fixture.usuario(id + "-b", Papel.CLIENTE);
        var cliente = fixture.usuario(id + "-cliente", Papel.CLIENTE);
        var owner = fixture.usuario(id + "-lojista", Papel.LOJISTA);
        var operacao = new DadosOperacionais();
        operacao.setTaxaEntregaBase(new BigDecimal("5.00"));
        operacao.setEntregaPropria(false); operacao.setRaioEntregaKm(new BigDecimal("20.00"));
        var loja = lojas.saveAndFlush(Loja.builder().id("it-" + id + "-loja")
                .usuarioId(owner.getId()).nome("Loja " + id).isAberto(true).dadosOperacionais(operacao)
                .geoLocalizacao(new GeoLocalizacao(-23.550520, -46.633308, "6gyf4"))
                .endereco(new EnderecoLoja("Praça da Sé", "1", "São Paulo", "SP", "01001-000", "Sé", "Teste"))
                .build());
        String pedido = "it-" + id + "-pedido", segundo = "it-" + id + "-segundo";
        fixture.pedido(pedido, cliente, loja); fixture.pedido(segundo, cliente, loja);
        return Map.of("a", ator(a), "b", ator(b), "cliente", ator(cliente), "lojaId", loja.getId(),
                "pedidoId", pedido, "segundoPedidoId", segundo, "lojista", ator(owner));
    }

    private Map<String,String> ator(Usuario u) {
        String base = String.format("8%08d", sequence.incrementAndGet());
        String cpf = base;
        for (int n = 9; n <= 10; n++) {
            int soma = 0;
            for (int i = 0; i < n; i++) soma += (cpf.charAt(i) - '0') * (n + 1 - i);
            int d = soma % 11 < 2 ? 0 : 11 - soma % 11;
            cpf += d;
        }
        return Map.of("id", u.getId(), "email", u.getEmail(), "telefone", u.getTelefone(), "cpf", cpf);
    }

    @PostMapping("/cenarios/{id}/encerrar")
    @Transactional
    public void encerrar(@PathVariable String id) {
        for (String ator : List.of("a", "b"))
            entregadores.findByUsuarioId("it-" + id + "-" + ator).ifPresent(e -> {
                e.setAtivo(false); e.setStatusOperacional(StatusOperacional.OFFLINE); entregadores.save(e);
            });
    }

    @PostMapping("/usuarios/{id}/{acao}")
    @Transactional
    public void estado(@PathVariable String id, @PathVariable String acao) {
        var e = entregadores.findByUsuarioId(id).orElseThrow();
        switch (acao) {
            case "gps-antigo" -> e.setUltimaAtualizacaoLocalizacao(Instant.now().minusSeconds(300));
            case "inativar" -> e.setAtivo(false);
            default -> throw new IllegalArgumentException("Ação de fixture desconhecida.");
        }
        entregadores.save(e);
    }

    @PostMapping("/pedidos/{id}/expirar-ofertas")
    @Transactional
    public void expirar(@PathVariable String id) {
        for (var o : ofertas.findByPedidoIdAndStatus(id, StatusOferta.PENDENTE)) {
            o.setExpiraEm(Instant.now().minusSeconds(1)); ofertas.save(o);
        }
    }

    @PostMapping("/pedidos/{id}/cancelamento-remoto")
    @Transactional
    public void cancelar(@PathVariable String id) {
        var p = pedidos.findById(id).orElseThrow();
        p.setStatus(StatusPedido.CANCELADO);
        if (p.getEntregador() != null) {
            var e = p.getEntregador(); e.setStatusOperacional(StatusOperacional.ONLINE); entregadores.save(e);
        }
        pedidos.save(p);
    }

    @GetMapping("/codigo")
    @Transactional
    public Map<String,String> codigo(@RequestParam(required=false) String email,
            @RequestParam(required=false) String telefone) {
        if ((email == null) == (telefone == null)) throw new IllegalArgumentException("Informe uma identidade.");
        if (email != null) return Map.of("codigo", emails
                .findTopByEmailAndUtilizadoFalseAndDataExpiracaoAfterOrderByCriadoEmDesc(email, LocalDateTime.now())
                .orElseThrow().getCodigo());
        return Map.of("codigo", sms
                .findTopByTelefoneAndUtilizadoFalseAndDataExpiracaoAfterOrderByCriadoEmDesc(telefone, LocalDateTime.now())
                .orElseThrow().getCodigo());
    }

    @PostMapping("/usuarios/{id}/historico")
    @Transactional
    public void historico(@PathVariable String id) {
        var e = entregadores.findByUsuarioId(id).orElseThrow();
        var loja = lojas.findById("it-loja").orElseThrow();
        var cliente = usuarios.findById("it-cliente").orElseThrow();
        // Fixtures de consulta/paginação, não simulam o fluxo de conclusão.
        for (int i = 0; i < 23; i++) {
            String pedidoId = id + "-h" + i;
            fixture.pedido(pedidoId, cliente, loja);
            var p = pedidos.findById(pedidoId).orElseThrow();
            p.setEntregador(e); p.setStatus(i == 22 ? StatusPedido.CANCELADO : StatusPedido.ENTREGUE);
            p.setEntregueEm(Instant.now().minusSeconds(i)); p.setColetadoEm(Instant.now().minusSeconds(i + 30));
            pedidos.save(p);
        }
    }
}
