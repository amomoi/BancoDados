def check_status  
  # Carrega sensor e cliente em memória (um SELECT só para cada)
  sensor  = Bdsensor.find_by(id: bdsensor_id)
  cliente = Bdcliente.find_by(id: sensor.bdcliente_id) if sensor

  return unless sensor && cliente

  Rails.logger.info "Cliente: #{cliente.id}, ativo_inativo=#{cliente.ativo_inativo}"
  Rails.logger.info "Sensor: #{sensor.id}, ativo_inativo=#{sensor.ativo_inativo}"

  # Usuários vinculados
  usuarios = Bdusuario.where(bdcliente_id: cliente.id).pluck(:celular, :SMS)
  Rails.logger.info "Usuarios: #{usuarios.inspect}"

  # Limites
  limite_inferior = sensor.LI.present? ? sensor.LI.to_f : nil
  limite_superior = sensor.LS.present? ? sensor.LS.to_f : nil

  Rails.logger.info "LI=#{limite_inferior.inspect} LS=#{limite_superior.inspect}"

  # Valor atual e anterior
  valor_f = valor.to_f
  valor_anterior = Bdleitura.where(bdsensor_id: bdsensor_id).last&.valor

  Rails.logger.info "Valor anterior=#{valor_anterior} atual=#{valor_f}"

  # Flags
  flag_notificacao = sensor.flag_notificacao.to_i
  flag_rearme      = sensor.flag_rearme.to_i
  flag_mantec      = sensor.flag_mantec.to_i

  Rails.logger.info "Flags: notificacao=#{flag_notificacao} rearme=#{flag_rearme} mantec=#{flag_mantec}"

  # Checa limites
  violou_inferior = limite_inferior.present? && valor_f <= limite_inferior
  violou_superior = limite_superior.present? && valor_f >= limite_superior
  fora_do_limite  = violou_inferior || violou_superior

  Rails.logger.info "violou_inf=#{violou_inferior} violou_sup=#{violou_superior} => fora_do_limite=#{fora_do_limite}"

  # Aplica lógica de manutenção/notificação
  if flag_mantec == 1
    sensor.update(flag_rearme: 0, flag_notificacao: 0)
    Rails.logger.info "Manutenção ativada, flags zerados"
  else
    if fora_do_limite
      if flag_notificacao == 0
        sensor.update(flag_notificacao: 1)
        Rails.logger.info "Notificação ativada (fora do limite)"
      end
    else
      if flag_notificacao == 1
        sensor.update(flag_notificacao: 0)
        Rails.logger.info "Valor dentro dos limites; notificação=0"
      end
    end
  end
end
