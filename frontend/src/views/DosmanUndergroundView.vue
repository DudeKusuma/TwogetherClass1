<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { ArrowLeft, Settings, X, Package } from 'lucide-vue-next'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/useAuthStore'

const auth = useAuthStore(), A = '/dosman/assets/'
const assets = {
 background:A+'lantern-lit-underground-mine-chamber.png', rupiah:A+'rupiah-icon.png',
  healthFrames:Array.from({length:6},(_,i)=>A+`cropped/health-frame-${i+1}.png`),
 rupiahStates:Array.from({length:3},(_,i)=>A+`cropped/rupiah-state-${i+1}.png`),
 goldSelection:Array.from({length:3},(_,i)=>A+`cropped/gold-selection-${i+1}.png`),
 inventorySlots:Array.from({length:4},(_,i)=>A+`cropped/inventory-slot-${i+1}.png`),
 backpackStates:Array.from({length:3},(_,i)=>A+`dosman-backpack-state-${i+1}.png`),
 chestStates:Array.from({length:3},(_,i)=>A+`dosman-chest-state-${i+1}.png`),
 portalStates:Array.from({length:3},(_,i)=>A+`dosman-portal-state-${i+1}.png`),
 storeStates:Array.from({length:3},(_,i)=>A+`dosman-store-state-${i+1}.png`),
 powerIcons:Array.from({length:3},(_,i)=>A+`cropped/power-upgrade-${i+1}.png`),
 speedIcons:Array.from({length:3},(_,i)=>A+`cropped/speed-upgrade-${i+1}.png`),
 oreIcons:Array.from({length:3},(_,i)=>A+`cropped/ore-upgrade-${i+1}.png`),
 luckIcons:Array.from({length:3},(_,i)=>A+`dosman-luck-icon-${i+1}.png`),
 ores:{dirt:A+'ore-dirt.png',stone:A+'ore-stone.png',coal:A+'ore-coal.png'},
 pickaxes:{wooden:A+'pickaxe-wooden.png',stone:A+'pickaxe-stone.png',iron:A+'pickaxe-iron.png'},
 swing:A+'pixel-art-pickaxe-swing-animation-sheet.png', portrait:A+'dark-fantasy-pixel-portrait-frame.png',
 inventory:A+'pixel-art-inventory-slot-states.png', card:A+'pixel-art-fantasy-card-frames-trio.png',
 upgrade:A+'three-tier-golden-ore-upgrade-icons.png', forge:A+'pixel-art-mining-forge-ui-panel.png',
 footer:A+'cropped/footer-bar.png', chest:A+'pixel-treasure-chest-evolution-set.png',
 portals:A+'pixel-dungeon-portals-active-states.png', stall:A+'pixel-art-mining-stall-states.png',
 pickDetail:A+'cropped/pickaxe-detail-panel.png', hud:A+'cropped/hud-panel.png',
 goldButton:A+'pixel-art-gold-button-state-set.png', slotIcons:A+'pixel-art-slot-indicator-icons.png'
}
const oreTypes=[
 {id:'dirt',name:'Dirt',rarity:'Common',chance:60,hp:[16,24,40],reward:[[2,10],[4,15],[7,22]]},
 {id:'stone',name:'Stone',rarity:'Uncommon',chance:30,hp:[48,64,96],reward:[[8,20],[12,30],[18,45]]},
 {id:'coal',name:'Coal',rarity:'Rare',chance:10,hp:[88,112,168],reward:[[15,35],[25,50],[35,75]]}
]
const sizes=[{name:'Small',scale:.75,weight:50},{name:'Medium',scale:1,weight:33.33},{name:'Large',scale:1.25,weight:16.67}]
const pickaxes=[{id:'wooden',name:'Wooden Pickaxe',multiplier:1},{id:'stone',name:'Stone Pickaxe',multiplier:1.5},{id:'iron',name:'Iron Pickaxe',multiplier:2}]
const state=ref({rupiah:0,power:0,speed:0,oreUpgrade:0,luck:0,equipped:'wooden',owned:['wooden','stone','iron'],totalMined:0})
const ore=ref(null),hp=ref(0),maxHp=ref(0),damageText=ref(''),rewardText=ref(''),rewardDrop=ref(null),swinging=ref(false)
const selectedPickaxe=ref('wooden')
const modal=ref(''),activeTab=ref('mining'),saveStatus=ref('Memuat...'),notice=ref('')
const lastManualHit=ref(0);let autoTimer,saveTimer,noticeTimer,pendingSave=false,saving=false,swingTimer
const equipped=computed(()=>pickaxes.find(p=>p.id===state.value.equipped)||pickaxes[0])
const power=computed(()=>Math.floor((1+state.value.power)*equipped.value.multiplier))
const healthPct=computed(()=>maxHp.value?Math.max(0,hp.value/maxHp.value*100):0)
const healthFrame=computed(()=>{const p=healthPct.value;const idx=p>=99?0:p>=80?1:p>=60?2:p>=35?3:p>0?4:5;return assets.healthFrames[idx]})
const upgradeIcon=(id)=>{const level=state.value[id],tier=level>=10?2:level>=5?1:0;const key={power:'powerIcons',speed:'speedIcons',oreUpgrade:'oreIcons',luck:'luckIcons'}[id];return assets[key][tier]}
const upgradeFrameLevel=(id)=>state.value[id]>=10?2:state.value[id]>=5?1:0
const costs={power:[10,25,60,140,300,650,1300,2500],speed:[25,60,130,260,500,900,1500,2400,3800,6000],oreUpgrade:[35,100,250,600,1300],luck:[50,140,350,800,1800]}
const upgrades=[{id:'power',label:'POWER',desc:'+1 Base Power',icon:'pickaxe'},{id:'speed',label:'SPEED',desc:'Auto mining lebih cepat',icon:'speed'},{id:'oreUpgrade',label:'ORE',desc:'+10% nilai reward',icon:'ore'},{id:'luck',label:'LUCK',desc:'Peluang bonus reward',icon:'luck'}]
const autoDelay=computed(()=>Math.max(800,2000-120*state.value.speed))
function choose(items,key='weight'){const total=items.reduce((a,x)=>a+x[key],0);let r=Math.random()*total;return items.find(x=>(r-=x[key])<=0)||items.at(-1)}
function spawnOre(){const t=choose(oreTypes,'chance'),s=choose(sizes),i=sizes.indexOf(s);ore.value={...t,size:s.name,scale:s.scale};maxHp.value=t.hp[i]*8;hp.value=maxHp.value}
function notify(msg){notice.value=msg;clearTimeout(noticeTimer);noticeTimer=setTimeout(()=>notice.value='',1800)}
function queueSave(){pendingSave=true;saveStatus.value='Belum disimpan';clearTimeout(saveTimer);saveTimer=setTimeout(flushSave,1500)}
async function saveNow(){clearTimeout(saveTimer);pendingSave=true;await flushSave()}
async function flushSave(){if(!pendingSave||saving||!auth.user?.id||!supabase)return;pendingSave=false;saving=true;saveStatus.value='Menyimpan...';const {error}=await supabase.from('dosman_game_saves').upsert({user_id:auth.user.id,save_data:state.value,updated_at:new Date().toISOString()},{onConflict:'user_id'});saving=false;if(error){pendingSave=true;saveStatus.value='Belum tersimpan';console.warn('Dosman save:',error.message)}else saveStatus.value='Tersimpan';if(pendingSave){clearTimeout(saveTimer);saveTimer=setTimeout(flushSave,20000)}}
function animateSwing(){swinging.value=true;clearTimeout(swingTimer);swingTimer=setTimeout(()=>swinging.value=false,420)}
function hit(manual=true){if(!ore.value||hp.value<=0)return;const now=Date.now();if(manual&&now-lastManualHit.value<500)return;if(manual){lastManualHit.value=now;startAuto()}animateSwing();const damage=Math.max(1,power.value);hp.value=Math.max(0,hp.value-damage);damageText.value='-'+damage;setTimeout(()=>damageText.value='',450);if(hp.value===0){const i=sizes.findIndex(s=>s.name===ore.value.size),[min,max]=ore.value.reward[i];let earned=Math.round(Math.floor(min+Math.random()*(max-min+1))*(1+.1*state.value.oreUpgrade));if(Math.random()<Math.min(.5,state.value.luck*.02))earned=Math.round(earned*1.5);state.value.rupiah+=earned;state.value.totalMined++;rewardText.value=`+Rp${earned.toLocaleString('id-ID')}`;rewardDrop.value={amount:earned,tier:earned>=500?2:earned>=100?1:0};setTimeout(()=>{rewardText.value='';rewardDrop.value=null},950);ore.value=null;setTimeout(spawnOre,700);queueSave()}}
function buy(id){const level=state.value[id],price=costs[id][level];if(price==null)return;if(state.value.rupiah<price){notify('Rupiah belum cukup!');return}state.value.rupiah-=price;state.value[id]++;queueSave();notify(`${id==='oreUpgrade'?'Ore':id[0].toUpperCase()+id.slice(1)} berhasil ditingkatkan!`)}
function openPickaxeDetail(id){selectedPickaxe.value=id;modal.value='pickaxe-detail'}
function equipSelected(){const id=selectedPickaxe.value;if(!state.value.owned.includes(id))return;if(id==='wooden'){notify('Wooden Pickaxe adalah pickaxe dasar dan selalu tersedia');return}state.value.equipped=id;queueSave();notify(`${pickaxes.find(p=>p.id===id).name} dipakai`)}
function unequipSelected(){if(selectedPickaxe.value==='wooden'){notify('Wooden Pickaxe adalah pickaxe dasar dan tidak bisa di-unequip');return}state.value.equipped='wooden';queueSave();notify('Kembali ke Wooden Pickaxe')}
const selectedPickaxeData=computed(()=>pickaxes.find(p=>p.id===selectedPickaxe.value)||pickaxes[0])
const pickaxeRarity=computed(()=>({wooden:-1,stone:0,iron:1}[selectedPickaxe.value]??-1))
const rarityArt=(id)=>assets.goldSelection[id==='stone'?0:1]
const pickaxeRarityLabel=computed(()=>({wooden:'Basic',stone:'Common',iron:'Uncommon'}[selectedPickaxe.value]||'Basic'))
const pickaxeDescription=computed(()=>({wooden:'Pickaxe dasar untuk memulai mining. Tidak dapat di-unequip.',stone:'Pickaxe batu yang lebih kuat untuk mining lebih cepat.',iron:'Pickaxe besi dengan damage mining tertinggi saat ini.'}[selectedPickaxe.value]||''))
function startAuto(){clearInterval(autoTimer);autoTimer=setInterval(()=>{if(document.visibilityState==='visible'&&activeTab.value==='mining')hit(false)},autoDelay.value)}
watch(autoDelay,startAuto)
function openTab(tab){if(tab==='mining'){activeTab.value='mining';modal.value='';return}activeTab.value=tab;modal.value=tab}
function onVisibility(){if(document.visibilityState==='hidden'){clearInterval(autoTimer);flushSave()}else if(activeTab.value==='mining')startAuto()}
const playerName=computed(()=>auth.user?.displayName||auth.user?.username||'Miner')
onMounted(async()=>{document.documentElement.classList.add('dosman-fullscreen');document.body.classList.add('dosman-fullscreen');spawnOre();if(supabase&&auth.user?.id){const {data,error}=await supabase.from('dosman_game_saves').select('save_data').eq('user_id',auth.user.id).maybeSingle();if(data?.save_data)state.value={...state.value,...data.save_data};if(error&&error.code!=='PGRST116')saveStatus.value='Mode lokal (migration belum aktif)'}if(saveStatus.value==='Memuat...')saveStatus.value='Siap';startAuto();document.addEventListener('visibilitychange',onVisibility)})
onBeforeUnmount(()=>{document.documentElement.classList.remove('dosman-fullscreen');document.body.classList.remove('dosman-fullscreen');clearInterval(autoTimer);clearTimeout(saveTimer);clearTimeout(swingTimer);clearTimeout(noticeTimer);document.removeEventListener('visibilitychange',onVisibility);flushSave()})
</script>

<template>
 <main class="dosman-page">
  <section v-if="activeTab==='mining'" class="mine-world" :style="{'--mine-bg':`url(${assets.background})`}" aria-label="Dosman Underground mining">
   <header class="topbar">
    <button class="profile-button" @click="modal='profile'" aria-label="Buka profile" :style="{'--hud-art':`url(${assets.hud})`}" type="button">
      <span class="portrait"><img :src="assets.portrait" alt=""><span class="portrait-mark">{{playerName.slice(0,1).toUpperCase()}}</span></span>
      <span class="profile-copy"><b>{{playerName}}</b><small>Dosman Miner · XI-B2</small></span>
    </button>
    <button class="icon-btn" aria-label="Pengaturan" @click="modal='settings'" type="button"><Settings/></button>
   </header>

   <div class="balance"><img :src="assets.rupiahStates[0]" alt="Ikon Rupiah"><b>Rp {{state.rupiah.toLocaleString('id-ID')}}</b></div>

   <section class="mine-panel">
    <div class="ore-meta"><span>{{ore?.name}} · {{ore?.rarity}}</span><span>{{ore?.size}}</span></div>
    <div class="health-sprite-wrap"><img class="health-sprite" :src="healthFrame" alt="Ore health"></div>
    <button class="ore-stage" aria-label="Pukul ore untuk mining" @click="hit(true)" type="button">
      <img v-if="ore" class="ore-art" :src="assets.ores[ore.id]" :alt="ore.name" :style="{transform:`scale(${ore.scale})`}">
      <strong v-if="damageText" class="damage">{{damageText}}</strong>
      <strong v-if="rewardText" class="reward">{{rewardText}}</strong>
      <div v-if="rewardDrop" class="currency-drop" aria-hidden="true">
        <img class="currency-drop-art" :src="assets.rupiahStates[rewardDrop.tier]" alt=""><b>+Rp{{rewardDrop.amount.toLocaleString('id-ID')}}</b>
      </div>
      <div class="swing-tool" :class="{swinging}" :style="{'--swing-sheet':`url(${assets.swing})`}" aria-hidden="true"></div>
      <span class="tap-hint">TAP AREA UNTUK MENAMBANG</span>
    </button>
    <p class="tool-line"><img :src="assets.pickaxes[equipped.id]" :alt="equipped.name"> <span>{{equipped.name}} · Power {{power}}</span></p>
   </section>

   <section class="upgrades" aria-label="Mining upgrades">
    <button v-for="u in upgrades" :key="u.id" class="upgrade-card" :class="'upgrade-'+u.id" :style="{'--forge-art':`url(${assets.forge})`}" :disabled="costs[u.id][state[u.id]]==null" @click="buy(u.id)" type="button">
      <span class="upgrade-icon"><img :src="upgradeIcon(u.id)" :alt="u.label+' upgrade level '+state[u.id]"></span>
      <b>{{u.label}}</b><small>LV {{state[u.id]}}</small><em>{{costs[u.id][state[u.id]]==null?'MAX':'Rp '+costs[u.id][state[u.id]].toLocaleString('id-ID')}}</em>
    </button>
   </section>
  </section>

  <nav class="footer" :style="{'--footer-art':`url(${assets.footer})`}" aria-label="Dosman navigation">
   <button :class="{active:activeTab==='backpack'}" @click="openTab('backpack')" type="button"><img :src="assets.backpackStates[activeTab==='backpack'?1:0]" alt=""><small>Backpack</small></button>
   <button :class="{active:activeTab==='gacha'}" @click="openTab('gacha')" type="button"><img :src="assets.chestStates[activeTab==='gacha'?1:0]" alt=""><small>Summon</small></button>
   <button :class="{active:activeTab==='mining'}" @click="openTab('mining')" type="button"><img :src="assets.pickaxes.wooden" alt=""><small>Mining</small></button>
   <button :class="{active:activeTab==='dungeon'}" @click="openTab('dungeon')" type="button"><img :src="assets.portalStates[activeTab==='dungeon'?1:0]" alt=""><small>Dungeon</small></button>
   <button :class="{active:activeTab==='store'}" @click="openTab('store')" type="button"><img :src="assets.storeStates[activeTab==='store'?1:0]" alt=""><small>Store</small></button>
  </nav>

  <div v-if="notice" class="notice">{{notice}}</div>

  <div v-if="modal" class="overlay" @click.self="modal='';activeTab='mining'">
   <section class="modal pixel-modal" role="dialog" aria-modal="true">
    <header class="modal-head">
      <h2>{{({profile:'PLAYER PROFILE',settings:'SETTINGS',backpack:'BACKPACK',gacha:'SUMMON / GACHA',dungeon:'DUNGEON',store:'STORE','pickaxe-detail':'PICKAXE DETAIL'})[modal]}}</h2>
      <button class="close-btn" @click="modal='';activeTab='mining'" type="button" aria-label="Tutup"><X/></button>
    </header>

    <template v-if="modal==='profile'">
      <div class="profile-hero"><img :src="assets.portrait" alt=""><div><b>{{playerName}}</b><small>Dosman Miner · Level {{1+Math.floor(state.totalMined/10)}}</small></div></div>
      <div class="stat-grid">
        <div><small>RUPIAH</small><b>Rp {{state.rupiah.toLocaleString('id-ID')}}</b></div>
        <div><small>ORE DITAMBANG</small><b>{{state.totalMined}}</b></div>
        <div><small>PICKAXE</small><b>{{equipped.name}}</b></div>
        <div><small>POWER</small><b>{{power}}</b></div>
      </div>
    </template>

    <template v-else-if="modal==='settings'">
      <div class="settings-row"><span>Save status</span><b>{{saveStatus}}</b></div>
      <button class="gold-action" @click="saveNow" type="button">SIMPAN SEKARANG</button>
      <p class="modal-note">Progress disimpan ke akun saat Supabase dan migration tersedia.</p>
    </template>

    <template v-else-if="modal==='backpack'">
      <div class="inventory-tabs"><span class="selected">PICKAXES</span><span>ORES</span><span>MATERIALS</span><span>ITEMS</span></div>
      <div class="inventory-grid">
        <button v-for="p in pickaxes" :key="p.id" class="inventory-slot" :class="{equipped:state.equipped===p.id}" :style="{'--slot-art':`url(${assets.inventorySlots[0]})`}" @click="openPickaxeDetail(p.id)" type="button">
          <span v-if="p.id!=='wooden'" class="rarity-frame" :style="{'--rarity-art':`url(${rarityArt(p.id)})`}"></span>
          <span class="slot-indicator" :class="{selected:selectedPickaxe===p.id}" aria-hidden="true"></span>
          <img :src="assets.pickaxes[p.id]" :alt="p.name"><small>{{p.name.replace(' Pickaxe','')}}</small><em>{{state.equipped===p.id?'EQUIPPED':'OWNED'}}</em>
        </button>
        <div v-for="n in 9" :key="'empty'+n" class="inventory-slot empty" :style="{'--slot-art':`url(${assets.inventorySlots[3]})`}"><Package/><small>Empty Slot</small></div>
      </div>
      <p class="modal-note">Pilih slot pickaxe untuk mengganti alat mining.</p>
    </template>

    <template v-else-if="modal==='pickaxe-detail'">
      <div class="pickaxe-detail-panel">
        <div v-if="pickaxeRarity>=0" class="pickaxe-detail-rarity" :style="{'--rarity-art':`url(${assets.goldSelection[pickaxeRarity]})`}"></div>
        <div class="pickaxe-detail-art"><img :src="assets.pickaxes[selectedPickaxeData.id]" :alt="selectedPickaxeData.name"></div>
        <div class="pickaxe-detail-copy">
          <h3>{{selectedPickaxeData.name}}</h3>
          <p>{{pickaxeDescription}}</p>
          <div class="pickaxe-stats"><span>RARITY <b>{{pickaxeRarityLabel}}</b></span><span>POWER <b>x{{selectedPickaxeData.multiplier}}</b></span><span>STATUS <b>{{state.equipped===selectedPickaxeData.id?'EQUIPPED':'OWNED'}}</b></span><span>OWNED <b>{{state.owned.includes(selectedPickaxeData.id)?'YES':'NO'}}</b></span></div>
          <div class="pickaxe-actions">
            <button class="gold-action" :disabled="state.equipped===selectedPickaxeData.id" @click="equipSelected" type="button">{{state.equipped===selectedPickaxeData.id?'EQUIPPED':'EQUIP'}}</button>
            <button v-if="selectedPickaxeData.id!=='wooden'" class="secondary-action" :disabled="state.equipped!=='wooden' && state.equipped!==selectedPickaxeData.id" @click="unequipSelected" type="button">UNEQUIP → WOODEN</button>
          </div>
        </div>
      </div>
    </template>

    <template v-else-if="modal==='gacha'">
      <div class="feature-visual"><img :src="assets.chestStates[2]" alt="Treasure chest"></div>
      <div class="feature-copy"><b>SUMMON CHAMBER</b><p>Tempat summon Hero dan Cosmetic. Sistem summon masih dalam tahap persiapan.</p></div>
      <div class="feature-pills"><span>HERO GACHA</span><span>COSMETIC GACHA</span></div>
    </template>

    <template v-else-if="modal==='dungeon'">
      <div class="feature-visual"><img :src="assets.portals[2]" alt="Dungeon portals"></div>
      <div class="feature-copy"><b>DUNGEON GATE</b><p>Gerbang dungeon akan menjadi tempat expedition dan tantangan. Fitur ini belum dibuka.</p></div>
      <div class="feature-pills"><span>EXPEDITION</span><span>COMING SOON</span></div>
    </template>

    <template v-else-if="modal==='store'">
      <div class="feature-visual"><img :src="assets.storeStates[2]" alt="Mining store"></div>
      <div class="feature-copy"><b>MINER'S STORE</b><p>Tempat melihat dan membeli perlengkapan serta kosmetik. Toko sedang disiapkan.</p></div>
      <div class="feature-pills"><span>TOOLS</span><span>COSMETICS</span></div>
    </template>
   </section>
  </div>
 </main>
</template>

<style scoped>

:global(html.dosman-fullscreen),:global(body.dosman-fullscreen),:global(body.dosman-fullscreen #app){width:100%;height:100%;margin:0!important;overflow:hidden!important}
.dosman-page{--gold:#f1b95f;position:fixed;inset:0;z-index:40;width:100%;height:100vh;height:100dvh;overflow:hidden;color:#f5e9d3;background:#100e0d;font-family:inherit;isolation:isolate}
.mine-world{height:100%;min-height:0;box-sizing:border-box;padding:calc(8px + env(safe-area-inset-top)) 12px calc(108px + env(safe-area-inset-bottom));background:linear-gradient(#100d0b45,#100d0bd9),var(--mine-bg) center 28%/cover no-repeat;display:flex;flex-direction:column;gap:7px;overflow:hidden}
.topbar{height:78px;flex:0 0 78px;display:flex;align-items:center;justify-content:space-between;gap:10px}
.profile-button{height:76px;width:min(230px,68vw);min-width:205px;max-width:230px;flex:0 0 auto;display:flex;align-items:center;gap:8px;border:0;background:var(--hud-art) center/100% auto no-repeat;color:#fff1d9;padding:5px 13px 5px 8px;text-align:left;image-rendering:pixelated}
.portrait{width:46px;height:46px;flex:0 0 46px;position:relative;display:grid;place-items:center}
.portrait img{position:absolute;inset:0;width:100%;height:100%;object-fit:contain;image-rendering:pixelated}
.portrait-mark{font-weight:900;color:#ffe0a0;text-shadow:2px 2px #542c19;font-size:18px}
.profile-copy{min-width:0;display:flex;flex-direction:column;gap:3px;text-shadow:1px 2px #130c08}
.profile-copy b{font-size:clamp(10px,3vw,13px);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.profile-copy small{font-size:9px;color:#d2b78d}
.icon-btn,.close-btn{width:44px;height:44px;flex:0 0 44px;border:0;background:url('/dosman/assets/pixel-art-gold-button-state-set.png') center/300% 100% no-repeat;background-position:50% 0;color:#f5d49d;display:grid;place-items:center}
.balance{display:flex;align-items:center;justify-content:center;gap:8px;width:180px;height:62px;max-width:100%;margin:0 auto;padding:0 10px;box-sizing:border-box;background:#21170fdc url('/dosman/assets/cropped/button-state-1.png') center/100% 100% no-repeat;color:#ffcf73}
.balance img{width:52px;height:40px;object-fit:contain;image-rendering:pixelated}
.balance b{font-size:15px}
.mine-panel{width:100%;max-width:620px;min-height:0;flex:1;margin:0 auto;padding:8px 10px 6px;box-sizing:border-box;background:#140f0ddd;border:2px solid #73502f;box-shadow:inset 0 0 0 2px #291c12;position:relative;display:flex;flex-direction:column;overflow:hidden}
.ore-meta{display:flex;justify-content:space-between;flex:0 0 auto;font-size:10px;color:#e2c69f;padding:1px 5px}
.health-sprite-wrap{height:78px;flex:0 0 78px;display:flex;align-items:center;justify-content:center;margin:2px 0 0}
.health-sprite{display:block;width:min(220px,55vw);height:auto;object-fit:contain;image-rendering:pixelated}
.ore-stage{width:100%;min-height:0;flex:1;border:0;background:radial-gradient(ellipse at 50% 66%,#c17a3430,transparent 58%);display:grid;place-items:center;position:relative;cursor:pointer;color:white;overflow:hidden;padding:0}
.ore-art{width:min(44vw,190px);height:min(23vh,170px);object-fit:contain;image-rendering:pixelated;filter:drop-shadow(0 10px 10px #000b);transition:transform .08s}
.tap-hint{position:absolute;bottom:4px;font-size:9px;letter-spacing:.1em;color:#f1c17d;background:#21170dcc;padding:5px 9px;border:1px solid #9a693c}
.swing-tool{position:absolute;z-index:2;right:calc(50% - 115px);top:18%;width:108px;height:118px;background-image:var(--swing-sheet);background-size:600% 300%;background-position:0% 0%;background-repeat:no-repeat;opacity:0;transform:rotate(20deg);transform-origin:70% 80%;pointer-events:none}
.swing-tool.swinging{opacity:1;animation:pickaxe-swing .42s steps(1) both}
@keyframes pickaxe-swing{0%{background-position:0% 0%;transform:rotate(28deg)}16%{background-position:20% 0%;transform:rotate(18deg)}32%{background-position:40% 0%;transform:rotate(0deg)}48%{background-position:60% 0%;transform:rotate(-24deg)}64%{background-position:80% 0%;transform:rotate(-8deg)}80%,100%{background-position:100% 0%;transform:rotate(18deg)}}
.damage,.reward{position:absolute;z-index:3;top:25%;left:50%;transform:translateX(-50%);text-shadow:2px 2px #000}
.damage{color:#ff7770;font-size:15px}.reward{color:#75ed8a;font-size:16px;white-space:nowrap}
.tool-line{display:flex;align-items:center;justify-content:center;gap:7px;margin:4px 0 0;color:#e7c18b;font-size:10px;flex:0 0 auto}
.tool-line img{width:27px;height:27px;object-fit:contain;image-rendering:pixelated}
.upgrades{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:5px;width:100%;max-width:620px;margin:0 auto;flex:0 0 auto;padding-top:0}
.upgrade-card{min-width:0;height:102px;padding:5px 2px 5px;border:0;background:var(--forge-art) center/100% 100% no-repeat;color:#f5e3c4;display:flex;align-items:center;flex-direction:column;justify-content:center;gap:2px;position:relative}
.upgrade-card:disabled{filter:grayscale(.5);opacity:.7}
.upgrade-icon{height:46px;width:48px;display:grid;place-items:center}
.upgrade-icon img{max-width:100%;max-height:44px;object-fit:contain;image-rendering:pixelated}
.upgrade-card b{font-size:9px;letter-spacing:.05em}.upgrade-card small{font-size:9px;color:#d5b68b}.upgrade-card em{font-style:normal;font-size:8px;color:#ffd16d;white-space:nowrap}
.footer{position:fixed;z-index:45;bottom:env(safe-area-inset-bottom);left:0;right:0;height:96px;padding:6px;display:grid;grid-template-columns:repeat(5,1fr);background:#17110df5 url('/dosman/assets/cropped/footer-bar.png') center bottom/auto 100% no-repeat;box-shadow:0 -7px 20px #0009;box-sizing:border-box}
.footer button{position:relative;border:0;background:transparent;color:#c0a27d;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:0;min-width:0}
.footer img{width:46px;height:46px;object-fit:contain;image-rendering:pixelated;filter:drop-shadow(1px 2px #130b06)}
.footer small{font-size:10px;text-shadow:1px 1px #100905}
.footer .active{color:#ffd06c;text-shadow:0 0 8px #d98932}
.footer .active:before{content:'';position:absolute;inset:0 5px;background:url('/dosman/assets/pixel-gold-selection-frames.png') center/300% 100% no-repeat;opacity:.7;pointer-events:none}
.overlay{position:fixed;inset:0;z-index:60;background:#080604e8;display:flex;align-items:center;justify-content:center;padding:calc(10px + env(safe-area-inset-top)) 10px calc(10px + env(safe-area-inset-bottom));box-sizing:border-box}
.modal{width:min(100%,540px);max-height:100%;overflow:auto;padding:14px;background:linear-gradient(145deg,#302016,#17110e);border:3px solid #96673a;box-shadow:inset 0 0 0 2px #4a2e19,0 0 0 2px #120b07;color:#f4e4ca;box-sizing:border-box}
.modal-head{display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid #79502e;padding-bottom:9px;margin-bottom:12px}
.modal-head h2{font-size:14px;letter-spacing:.09em;color:#ffd17b;margin:0}
.close-btn{width:32px;height:32px;flex:0 0 32px}
.profile-hero{display:flex;align-items:center;gap:13px;padding:12px;background:#100c09;border:1px solid #76502f}
.profile-hero img{width:72px;height:72px;object-fit:contain}.profile-hero div{display:flex;flex-direction:column;gap:5px}
.profile-hero b{font-size:15px}.profile-hero small,.modal-note{font-size:10px;color:#c7aa83}
.stat-grid{display:grid;grid-template-columns:1fr 1fr;gap:7px;margin-top:10px}
.stat-grid div{padding:10px;background:#17100c;border:1px solid #644327;display:flex;flex-direction:column;gap:5px}
.stat-grid small{font-size:8px;color:#c19b6c}.stat-grid b{font-size:11px;color:#ffe0a0}
.settings-row{display:flex;justify-content:space-between;padding:12px;background:#17100c;font-size:11px}
.settings-row b{color:#f2c16e}
.back-action,.gold-action{width:100%;margin:0 0 12px;padding:11px;border:2px solid #d39a4d;background:#53351c;color:#ffdc91;font-weight:900;letter-spacing:.08em;display:flex;align-items:center;justify-content:center;gap:8px}
.back-action svg{width:16px;height:16px}
.gold-action{margin-top:12px}
.inventory-tabs{display:grid;grid-template-columns:repeat(4,1fr);gap:4px;margin-bottom:10px}
.inventory-tabs span{text-align:center;padding:7px 2px;background:#17100c;border:1px solid #624329;color:#b89a73;font-size:8px}
.inventory-tabs .selected{background:#51351d;color:#ffe0a0;border-color:#d29a4f}
.inventory-grid{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:7px}
.inventory-slot{aspect-ratio:1/1.12;min-width:0;padding:5px 2px;position:relative;background:var(--slot-art) center/100% 100% no-repeat;display:flex;align-items:center;justify-content:center;flex-direction:column;gap:3px;color:#f3d7a9;border:0}
.inventory-slot.equipped{filter:drop-shadow(0 0 5px #d78c36)}
.inventory-slot img{width:70%;height:56px;object-fit:contain;image-rendering:pixelated}
.inventory-slot small{font-size:8px;text-align:center}.inventory-slot em{font-style:normal;font-size:7px;color:#f2bd63}
.inventory-slot.empty{opacity:.55}.inventory-slot.empty svg{width:23px;height:23px;color:#a98a66}
.feature-visual{height:160px;display:grid;place-items:center;background:radial-gradient(ellipse,#9d682c44,transparent 70%);overflow:hidden}
.feature-visual img{max-width:90%;max-height:150px;object-fit:contain;image-rendering:pixelated}
.feature-copy{text-align:center;padding:8px}.feature-copy b{font-size:13px;color:#ffcf77}
.feature-copy p{font-size:10px;line-height:1.6;color:#cbb393}
.feature-pills{display:flex;justify-content:center;gap:7px;flex-wrap:wrap}
.feature-pills span{padding:7px 9px;border:1px solid #8b6037;background:#21160f;color:#eac17e;font-size:8px}

.currency-drop{position:absolute;z-index:6;left:50%;top:56%;display:flex;flex-direction:column;align-items:center;gap:0;pointer-events:none;animation:currency-fly 950ms ease-out forwards;transform:translate(-50%,0)}
.currency-drop-art{width:58px;height:42px;object-fit:contain;image-rendering:pixelated;filter:drop-shadow(0 3px 3px #000c)}
.currency-drop b{font-size:10px;color:#ffd46e;text-shadow:1px 1px #000;white-space:nowrap}
@keyframes currency-fly{0%{opacity:0;transform:translate(-50%,8px) scale(.7)}18%{opacity:1}70%{opacity:1;transform:translate(-50%,-82px) scale(1)}100%{opacity:0;transform:translate(-50%,-125px) scale(.9)}}
.pickaxe-detail-panel{position:relative;min-height:300px;padding:18px;box-sizing:border-box;background:url('/dosman/assets/cropped/pickaxe-detail-panel.png') center/100% 100% no-repeat;display:grid;grid-template-columns:42% 58%;align-items:center;gap:4px;overflow:hidden}
.pickaxe-detail-rarity{position:absolute;left:21px;top:28px;width:122px;height:122px;background:var(--rarity-art) center/100% 100% no-repeat;image-rendering:pixelated;pointer-events:none}
.rarity-frame{position:absolute;inset:3px;z-index:0;background:var(--rarity-art) center/100% 100% no-repeat;pointer-events:none;opacity:.9}.slot-indicator{position:absolute;inset:0;z-index:2;background:url('/dosman/assets/pixel-art-slot-indicator-icons.png') 50% 0/300% 100% no-repeat;pointer-events:none;opacity:0}.slot-indicator.selected{opacity:1}
.pickaxe-detail-art{position:relative;z-index:1;display:grid;place-items:center;min-height:170px}
.pickaxe-detail-art img{width:130px;height:130px;object-fit:contain;image-rendering:pixelated;filter:drop-shadow(0 7px 5px #000b)}
.pickaxe-detail-copy{position:relative;z-index:1;padding:10px 14px 10px 6px}
.pickaxe-detail-copy h3{margin:0 0 8px;color:#ffd273;font-size:15px;text-shadow:2px 2px #261209}
.pickaxe-detail-copy p{margin:0 0 12px;color:#d7c09e;font-size:9px;line-height:1.6}
.pickaxe-stats{display:grid;grid-template-columns:1fr 1fr;gap:5px;margin-bottom:8px}.pickaxe-stats span{padding:6px;background:#1a100b99;border:1px solid #754a26;color:#b9956b;font-size:7px}.pickaxe-stats b{display:block;color:#ffe09a;font-size:9px;margin-top:2px}
.pickaxe-actions{display:grid;gap:5px}.pickaxe-actions .gold-action{margin:0;padding:8px;font-size:9px}.pickaxe-actions .gold-action:disabled{opacity:.5}.secondary-action{width:100%;padding:8px;border:1px solid #956333;background:#26180f;color:#e8c58f;font-size:8px;font-weight:800}
.notice{position:fixed;z-index:70;left:50%;bottom:calc(88px + env(safe-area-inset-bottom));transform:translateX(-50%);padding:9px 14px;background:#24170f;border:1px solid #d99c50;color:#ffdf9a;font-size:11px;white-space:nowrap;box-shadow:0 5px 18px #0009;max-width:90vw}
@media(max-height:700px){.footer{height:86px}.mine-world{padding-bottom:calc(98px + env(safe-area-inset-bottom))}.topbar{height:70px;flex-basis:70px}.profile-button{height:68px;width:min(205px,76vw);min-width:190px}.portrait{width:40px;height:40px;flex-basis:40px}.mine-world{gap:5px}.health-sprite-wrap{height:66px;flex-basis:66px}.health-sprite{width:min(190px,58vw)}.upgrade-card{height:88px}.upgrade-icon{height:38px}.upgrade-icon img{max-height:36px}.footer{height:86px}}
@media(max-width:520px){.modal{width:calc(100% - 20px);padding:10px}.pickaxe-detail-panel{min-height:270px;grid-template-columns:40% 60%;padding:14px}.pickaxe-detail-rarity{width:96px;height:96px;left:16px;top:24px}.pickaxe-detail-art img{width:105px;height:105px}.pickaxe-detail-copy{padding-right:8px}.pickaxe-detail-copy h3{font-size:13px}.pickaxe-detail-copy p{font-size:8px}.balance{width:170px;height:58px}.balance img{width:50px;height:38px}.profile-button{width:220px;min-width:200px}}
@media(min-width:768px){.mine-world{padding-left:24px;padding-right:24px}.footer{left:50%;right:auto;transform:translateX(-50%);width:min(100%,760px);border-left:2px solid #956335;border-right:2px solid #956335}}
</style>
