class Bdleitura < ApplicationRecord
    belongs_to :bdsensor

    before_save :check_status

    def check_status  
        # Carrega o sensor e o cliente associado de uma vez
        sensor = Bdsensor.find_by(id: bdsensor_id)
        # Se o sensor não existir, aborta o salvamento
        unless sensor
            errors.add(:base, "Sensor não encontrado.")
            throw(:abort)
        end

        cliente = Bdcliente.find_by(id: sensor.bdcliente_id)
        # Se o cliente não existir, aborta o salvamento
        unless cliente
            errors.add(:base, "Cliente não encontrado.")
            throw(:abort)
        end

        p "Cliente: #{cliente.id}"
        p "Cliente Ativo/Inativo: #{cliente.ativo_inativo}"
        p "Sensor ID: #{sensor.id}"
        p "Sensor Ativo/Inativo: #{sensor.ativo_inativo}"

        # Carrega as flags e limites uma única vez do objeto sensor carregado
        # Usaremos sensor.flag_notificacao diretamente para obter o valor mais recente
        # e atualizá-lo em memória se o banco for atualizado.
        flag_mantec = sensor.flag_mantec.to_i
        limite_inferior = sensor.LI.to_f if sensor.LI.present?
        limite_superior = sensor.LS.to_f if sensor.LS.present?

        # --- Inicializa valor_f SEMPRE com o valor da leitura ---
        valor_f = self.valor.to_f # 'valor' é o atributo da Bdleitura que está sendo salva
                                 # Garante que valor_f sempre tenha um valor float da leitura.

        
        #valor_f = valor.to_f # 'valor' é o atributo da Bdleitura que está sendo salva

        # --- NOVA LÓGICA PARA ARG5 (CALIBRAÇÃO) ---
        if sensor.arg5.present?
            calibracao_offset = sensor.arg5.to_f
            self.valor = (calibracao_offset).to_s # Aplica o offset e salva como string
            Rails.logger.info "Sensor #{sensor.id} - Calibração aplicada: valor offset '#{calibracao_offset}' = novo valor '#{self.valor}'"
            
            # Zera arg5 imediatamente após usar
            sensor.update(arg5: nil) # Ou sensor.update(arg5: "") dependendo do que a API espera para "vazio"
            Rails.logger.info "Sensor #{sensor.id} - arg5 zerado após uso."
            valor_f = self.valor.to_f # Atualiza valor_f para a lógica de limites a seguir
        end
        # --- FIM DA NOVA LÓGICA ---

        # Lógica de verificação de status do cliente e sensor
        if cliente.ativo_inativo != 1 || sensor.ativo_inativo != 1
            errors.add(:base, "Salvamento cancelado pois cliente ou sensor está inativo.")
            throw(:abort)
        end

        # Lógica de Manutenção (flag_mantec)
        if flag_mantec == 1
            # Atualiza o banco de dados e imediatamente atualiza o objeto `sensor` em memória
            sensor.update(flag_rearme: 0, flag_notificacao: 0)
            Rails.logger.info "Manutenção ativada para Sensor #{sensor.id}, flags zerados: flag_rearme=0, flag_notificacao=0"
            return # Sai do método check_status
        end

        # Lógica de verificação de limites (se não estiver em manutenção)
        violou_inferior = limite_inferior.present? && (valor_f <= limite_inferior)
        violou_superior = limite_superior.present? && (valor_f >= limite_superior)
        fora_do_limite = violou_inferior || violou_superior

        Rails.logger.info "Sensor #{sensor.id} - LI=#{limite_inferior.inspect} LS=#{limite_superior.inspect} " \
                       "Valor=#{valor_f} => violou_inf=#{violou_inferior} violou_sup=#{violou_superior}"

        # Obtém o valor atual da flag_notificacao ANTES de qualquer alteração,
        # para decidir se a notificação precisa ser ativada/desativada.
        current_flag_notificacao = sensor.flag_notificacao.to_i
        current_flag_rearme = sensor.flag_rearme.to_i

            if fora_do_limite
                  # fora do(s) limite(s)
                  if current_flag_notificacao == 0 # Só atualiza para 1 se ainda não estiver 1
                  sensor.update(flag_notificacao: 1)
                  # O objeto `sensor` em memória agora tem o novo valor de flag_notificacao
                  Rails.logger.info "Sensor #{sensor.id} - Notificação ativada (fora do limite): flag_notificacao=1"
                  end
            else
                  # dentro do(s) limite(s) definidos (ou nenhum limite definido)
                  if current_flag_notificacao == 1 || current_flag_rearme == 1 # Só atualiza se precisar zerar
                  sensor.update(flag_notificacao: 0, flag_rearme: 0)
                  # O objeto `sensor` em memória agora tem os novos valores
                  Rails.logger.info "Sensor #{sensor.id} - Valor dentro dos limites; flags zerados: flag_notificacao=0, flag_rearme=0"
                  end
            end
            
      end
end

# O bloco de código comentado abaixo da classe não faz parte da classe e não será executado
# a menos que esteja dentro de um método ou uma inicialização. Mantenha-o fora da classe.
# Para SMS, geralmente essa lógica fica em um service ou job separado, ou dentro do BdleituraController
# após o salvamento da leitura, se for algo a ser feito logo em seguida.

# if cliente_ativo_inativo == 1 && sensor_ativo_inativo == 1
            #       sms_ativo = Bdusuario.where("Bdcliente_id = ?", cliente[0]).select(:SMS).select(:nome).select(:ativo_inativo).select(:celular)

            #       sms_ativo.each do |s|
            #             if s[:SMS] == "1"

            #                   #AQUISICAO DOS PARAMETROS PARA LOGICA

            #                   p "LI"
            #                   results = Bdsensor.where("id = ?", bdsensor_id).select(:LI).pluck(:LI)
            #                   if results.all?(&:blank?) #= 'nil'
            #                         limite_inferior = ""
            #                         p limite_inferior
            #                   else 
            #                         limite_inferior = Bdsensor.where("id = ?", bdsensor_id).select(:LI).pluck(:LI).first.to_f
            #                         p limite_inferior
            #                   end

            #                   p "LS"
            #                   results = Bdsensor.where("id = ?", bdsensor_id).select(:LS).pluck(:LS)
            #                   if results.all?(&:blank?) #= 'nil'
            #                         limite_superior = ""
            #                         p limite_superior               
            #                   else 
            #                         limite_superior = Bdsensor.where("id = ?", bdsensor_id).select(:LS).pluck(:LS).first.to_f
            #                         p limite_superior
            #                   end

            #                   p "Valor anterior"
            #                   results = Bdleitura.where("bdsensor_id = ?", bdsensor_id).select(:valor)
            #                   if results.all?(&:blank?) #= 'nil'
            #                         p ""
            #                         p "Valor"
            #                         p valor
            #                   else 
            #                         valor_anterior = valor_anterior = Bdleitura.where("bdsensor_id = ?", bdsensor_id).select(:valor).last
            #                         p valor_anterior.valor
            #                         p "Valor"
            #                         p valor
            #                   end  


            #                   p "Flag notificacao"
            #                   results = Bdsensor.where("id = ?", bdsensor_id).select(:flag_notificacao).pluck(:flag_notificacao)
            #                   if results.all?(&:blank?) #= 'nil'
            #                         p flag_notificacao = ""
            #                   else 
            #                         flag_notificacao = Bdsensor.where("id = ?", bdsensor_id).select(:flag_notificacao).pluck(:flag_notificacao).first.to_i
            #                         p flag_notificacao
            #                   end

            #                   p "Flag rearme"
            #                   results = Bdsensor.where("id = ?", bdsensor_id).select(:flag_rearme).pluck(:flag_rearme)
            #                   if results.all?(&:blank?) #= 'nil'
            #                         p flag_rearme = ""                  
            #                   else 
            #                         flag_rearme = Bdsensor.where("id = ?", bdsensor_id).select(:flag_rearme).pluck(:flag_rearme).first.to_i
            #                         p flag_rearme
            #                   end

            #                   p "Flag mantec"
            #                   results = Bdsensor.where("id = ?", bdsensor_id).select(:flag_mantec).pluck(:flag_mantec)
            #                   if results.all?(&:blank?) #= 'nil'
            #                         p flag_mantec = ""
            #                   else 
            #                         flag_mantec = Bdsensor.where("id = ?", bdsensor_id).select(:flag_mantec).pluck(:flag_mantec).first.to_i
            #                         p flag_mantec
            #                   end

            #                   if limite_inferior != "" || limite_superior != "" 
            #                         if flag_mantec == 0 || flag_mantec == ""
            #                               if !limite_inferior != "" || !limite_superior != ""
            #                                     if valor <= limite_inferior || valor >= limite_superior #checa se atingiu o valor limite (superior ou inferior)
            #                                           p "Usuario ativo ou inativo"
            #                                           p s[:ativo_inativo]
            #                                           if s[:ativo_inativo] == 1
            #                                                 nome_da_empresa = Bdcliente.where("id = ?", cliente[0]).select(:nome_empresa).pluck(:nome_empresa)
            #                                                 p nome_da_empresa[0]
            #                                                 p bdsensor.nome_sensor
            #                                                 p "#{nome_da_empresa[0]} - #{s.nome}: SMS do Sensor #{bdsensor.nome_sensor} foi ativado #{Time.now.strftime("%I:%M%p - %d/%m/%Y")} pois atingiu o limite! Favor verificar!"
            #                                                 p "Enviou SMS por Leituras Controler"
            #                                                 BdleiturasController.enviarSMS(s[:celular], cliente[0], nome_da_empresa[0], s[:nome], bdsensor.nome_sensor)
            #                                           else
            #                                                 p "Nao enviou SMS pois usuario esta inativo"
            #                                           end 
            #                                     end
            #                               end
            #                         else #flag_mantec = 1
            #                               flag_notificacao = 0
            #                               flag_rearme = 0
            #                               p "Ativou Manutenção"
            #                         end
            #                   else
            #                         p "Nao tem LI ou LS cadastrado"
            #                   end
            #             else
            #                   p   "SMS desativado"
            #             end
            #       end
            # else

                  # #CANCELA SALVAMENTO POIS CLIENTE OU SENSOR ESTA INATIVO
                  # errors.add(:base, "Salvamento cancelado pois cliente ou sensor esta inativo")
                  # throw(:abort)
            #end