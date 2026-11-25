import json
SRC="/home/claude/game_data_orig.json"; DST="/home/claude/vo/data/game_data.json"
d=json.load(open(SRC,encoding="utf-8"))
R={r["id"]:r for r in d["rooms"]}
d["final_destination_id"]="sala_monitoramento"

R["room_3"]["connection_notes"]="Prompt 1: parede leste construída (x −3,5) com porta de 3 m em z −72,5…−69,5 para o corredor do nó Exit. Os dois vãos da parede oeste, que davam para o vazio, foram fechados."
R["room_3"]["pending_items"]=[p for p in R["room_3"]["pending_items"] if not p.startswith("Cenário:") and not p.startswith("Navegação:")]
R["room_4"]["connection_notes"]="Porta real de 3 m na parede leste (z −97,0…−94,0) para o Corredor 3. Prompt 1: removidas as peças de parede duplicadas (WallEast*) que fechavam o vão."
r6=R["room_6"]
r6["navigation_layer"]=6
r6["connected_area_paths"]=["School/Corridor5"]
r6["connection_notes"]="Prompt 1: ligada ao fim do Corredor 4 pelo Corredor 5 (x −3,5…3,5, z −138…−190). Porta de 3 m na parede leste da sala (z −176,5…−173,5)."
r6["technical_notes"]="Estrutura física provisória (Prompt 1: paredes no padrão da escola, vão sul fechado, porta leste, iluminação). Conteúdo musical e mecanismos narrativos ainda pendentes."
r6["pending_items"]=[p for p in r6["pending_items"] if not p.startswith("Cenário inexistente")]+["Móveis/objetos: a sala está vazia; reassar o navmesh com tools/bake_all_navmesh.gd -- --force quando houver móveis."]
for rid in ["room_2","room_3","room_4","room_5"]:
    R[rid]["pending_items"]=[p.replace("tools/bake_rooms_navmesh.gd","tools/bake_all_navmesh.gd") for p in R[rid]["pending_items"]]

d["rooms"].append({
  "id":"sala_inicial","kind":"STORY_AREA","display_name":"Sala onde a protagonista acorda","content_status":"PROVISIONAL",
  "geometry_status":"PHYSICAL","scene_anchor":"School/InitialRoom","narrative_tier":1,
  "technical_notes":"Local narrativo do despertar (lore, seção 6). Criado no Prompt 1 para que a porta da sala (sala_inicial.porta) pertença a um local do banco. Sem navmesh próprio: a área entra no navmesh dos corredores (camada 7).",
  "connected_area_paths":["School/Corridor"],
  "connection_notes":"Porta de 3 m na parede sul (x −1,5…1,5, z −4) para o Corredor 1."
})
d["rooms"].append({
  "id":"sala_monitoramento","kind":"STORY_AREA","display_name":"Sala de Monitoramento","content_status":"PROVISIONAL",
  "geometry_status":"PHYSICAL","scene_anchor":"School/SalaMonitoramento","narrative_tier":3,
  "technical_notes":"Prompt 1: estrutura física do final (lore, seção 6). Acesso pelo fim do Corredor 5 (porta trancada, modo manual), rampa até y −6, corredor subterrâneo e sala x −17,5…−3,5, z −226…−212. Monitores são placas emissivas provisórias; gravação, falas e sequência final ficam para o Prompt 5.",
  "connected_area_paths":["School/Subsolo"],
  "connection_notes":"Porta de 3 m na parede leste (z −220,5…−217,5) para o corredor subterrâneo.",
  "navigation_layer":8,"navigation_mesh":"res://data/navigation/subsolo_navmesh.tres","navigation_region_path":"Navigation/SubsoloNavigation"
})

def door(oid, room, node, lock, lroom=None, pending=False, notes=""):
    cfg={"lock":lock}
    if lroom: cfg["room_id"]=lroom
    if pending: cfg["allow_if_previous_pending"]=True
    return {"id":oid,"room_id":room,"implementation":"FUNCTIONAL","scene_node":node,"action":"abrir","prompt":"E  Abrir","door":cfg,"effects":[],"notes":notes}
N="Sala de aula: trancada enquanto a sala estiver LOCKED (até a sala anterior ser concluída)."
P=N+" Destrancada enquanto a sala anterior for PENDING (sem conteúdo para concluir) — rever no Prompt 4."
d["objects"]+=[
  door("sala_inicial.porta","sala_inicial","School/Doors/PortaInicial/Interactable","none",notes="Porta da sala do despertar; nunca tranca."),
  door("room_1.porta","room_1","School/Doors/PortaRoom1/Interactable","room_available","room_1",notes=N+" A room_1 começa AVAILABLE."),
  door("room_2.porta","room_2","School/Doors/PortaRoom2/Interactable","room_available","room_2",notes=N+" Abre quando a room_1 for concluída."),
  door("room_3.porta","room_3","School/Doors/PortaArtes/Interactable","room_available","room_3",True,P),
  door("room_4.porta","room_4","School/Doors/PortaRoom3/Interactable","room_available","room_4",True,P),
  door("room_5.porta","room_5","School/Doors/PortaRoom4/Interactable","room_available","room_5",True,P),
  door("room_6.porta","room_6","School/Doors/PortaMusica/Interactable","room_available","room_6",True,P),
  door("sala_monitoramento.porta_subsolo","sala_monitoramento","School/Doors/PortaSubsolo/Interactable","manual",notes="Acesso ao subsolo (fim do Corredor 5). Trancada até um efeito {\"type\": \"unlock_door\", \"door_id\": \"sala_monitoramento.porta_subsolo\"} — o gatilho real (mapa do Cartógrafo / conclusão da Música) é definido no Prompt 4."),
  door("sala_monitoramento.porta","sala_monitoramento","School/Doors/PortaMonitoramento/Interactable","none",notes="Porta da Sala de Monitoramento (subsolo)."),
]
s=json.dumps(d,ensure_ascii=False,indent=2)+"\n"
open(DST,"w",encoding="utf-8").write(s)
print("ok")
