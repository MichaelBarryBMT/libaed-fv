!###############################################################################
!#                                                                             #
!# fv_zones.F90                                                                #
!#                                                                             #
!# Interface for FV (Finite Volume) Model to AED2 modules.                     #
!#   Designed for TUFLOW-FV, released by BMT-WBM:                              #
!#   http://www.tuflow.com/Tuflow%20FV.aspx                                    #
!#                                                                             #
!# This is a support module to allow ability for benthic/sediment zones in     #
!# AED2, including zone-averaging                                              #
!#                                                                             #
!#   -----------------------------------------------------------------------   #
!#                                                                             #
!# Developed by :                                                              #
!#     AquaticEcoDynamics (AED) Group                                          #
!#     School of Agriculture and Environment                                   #
!# (C) The University of Western Australia                                     #
!#                                                                             #
!# Copyright by the AED-team @ UWA under the GNU Public License - www.gnu.org  #
!#                                                                             #
!#   -----------------------------------------------------------------------   #
!#                                                                             #
!# Created Apr 2015                                                            #
!#                                                                             #
!###############################################################################

#include "aed.h"

#ifndef DEBUG
#define DEBUG      0
#endif

!###############################################################################
MODULE fv_zones
!-------------------------------------------------------------------------------
   USE aed_common

   IMPLICIT NONE

   PRIVATE

   PUBLIC init_zones, calc_zone_areas, copy_to_zone, copy_from_zone
   PUBLIC compute_zone_benthic_fluxes, aed_initialize_zone_benthic
   PUBLIC STOPIT
   PUBLIC zone, zm, flux_pelz, flux_benz

   !#--------------------------------------------------------------------------#
   !# Module Data

   !# Arrays for environmental variables not supplied externally.
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone
   AED_REAL,DIMENSION(:,:),ALLOCATABLE,TARGET :: zone_cc
   AED_REAL,DIMENSION(:,:),ALLOCATABLE,TARGET :: zone_cc_diag
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_area
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_temp
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_salt
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_rho
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_height
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_extc
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_tss
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_par
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_nir
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_uva
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_uvb
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_wind
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_rain
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_rainloss
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_air_temp
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_humidity
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_bathy
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_I_0
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_longwave
   AED_REAL,DIMENSION(:),  ALLOCATABLE,TARGET :: zone_colnums
   INTEGER, DIMENSION(:),  ALLOCATABLE        :: zone_count, zm

   AED_REAL,DIMENSION(:,:),ALLOCATABLE,TARGET :: flux_pelz
   AED_REAL,DIMENSION(:,:),ALLOCATABLE,TARGET :: flux_benz

   AED_REAL,TARGET :: zone_taub

   INTEGER :: nZones, nwq_var, nben_var, ndiag_var

!#####################################################

CONTAINS
!===============================================================================


!###############################################################################
SUBROUTINE init_zones(nCols, mat_id, avg, n_vars, n_vars_ben, n_vars_diag)
!-------------------------------------------------------------------------------
!ARGUMENTS
   INTEGER,INTENT(in) :: nCols
   INTEGER,DIMENSION(:,:),INTENT(in) :: mat_id
   LOGICAL,INTENT(in) :: avg
   INTEGER,INTENT(in) :: n_vars, n_vars_ben, n_vars_diag
!
!LOCALS
   INTEGER :: i,j, cType, nTypes
   INTEGER :: col, zon
   INTEGER,DIMENSION(:),ALLOCATABLE :: mat_t
!
!-------------------------------------------------------------------------------
!BEGIN
   ALLOCATE(mat_t(nCols)) ; ALLOCATE(zm(nCols))
   mat_t = 0   ; zm = 1 ; zon = 1
   !# The new form of zones
   cType = mat_id(1,1) ; nTypes = 1 ; mat_t(nTypes) = mat_id(1,1)
   DO col=1, ubound(mat_id,2)
      !# use the bottom index to fill the array
!     print*, mat_id(1,col)
      IF ( cType /= mat_id(1,col) ) THEN
         DO zon=1,nTypes
            IF ( mat_t(zon) .eq. mat_id(1,col) ) THEN
               cType = mat_id(1,col)
               EXIT
            ENDIF
         ENDDO
      ENDIF
      IF ( cType /= mat_id(1,col) ) THEN
         nTypes = nTypes + 1
         mat_t(nTypes) = mat_id(1,col)
         cType = mat_id(1,col)
         zon = nTypes
      ENDIF
      zm(col) = zon
   ENDDO
   print*,"Number of mats = ", nTypes, " = ", mat_t(1:nTypes)
   nZones = nTypes

   ALLOCATE(zone(nZones))
   ALLOCATE(zone_colnums(nZones))
   DO zon=1,nZones
      zone(zon) = mat_t(zon)
      zone_colnums(zon) = zon
   ENDDO
   DEALLOCATE(mat_t)

   ALLOCATE(flux_pelz(n_vars+n_vars_ben, nZones)) ; flux_pelz = 0.
   ALLOCATE(flux_benz(n_vars+n_vars_ben, nZones)) ; flux_benz = 0.

   IF ( .NOT. avg ) RETURN

   ALLOCATE(zone_area(nZones))
   ALLOCATE(zone_temp(nZones))
   ALLOCATE(zone_salt(nZones))
   ALLOCATE(zone_rho(nZones))
   ALLOCATE(zone_height(nZones))

   ALLOCATE(zone_extc(nZones))
   ALLOCATE(zone_tss(nZones))
   ALLOCATE(zone_par(nZones))
   ALLOCATE(zone_nir(nZones))
   ALLOCATE(zone_uva(nZones))
   ALLOCATE(zone_uvb(nZones))
   ALLOCATE(zone_wind(nZones))
   ALLOCATE(zone_rain(nZones))
   ALLOCATE(zone_rainloss(nZones))
   ALLOCATE(zone_air_temp(nZones))
   ALLOCATE(zone_humidity(nZones))
   ALLOCATE(zone_bathy(nZones))
   ALLOCATE(zone_I_0(nZones))
   ALLOCATE(zone_longwave(nZones))
!  ALLOCATE(zone_taub(nZones))

   ALLOCATE(zone_count(nZones))

   ALLOCATE(zone_cc(n_vars+n_vars_ben, nZones))
   ALLOCATE(zone_cc_diag(n_vars_diag, nZones))

   nwq_var = n_vars
   nben_var = n_vars_ben
   ndiag_var = n_vars_diag
END SUBROUTINE init_zones
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


!###############################################################################
SUBROUTINE calc_zone_areas(nCols, active, temp, salt, h, area, wnd, rho,       &
                           extcoeff, I_0, longwave, par, tss, rain, rainloss,  &
                           air_temp, humidity, bathy, col_taub)
!-------------------------------------------------------------------------------
!ARGUMENTS
   INTEGER,INTENT(in) :: nCols
   LOGICAL,DIMENSION(:), INTENT(in) :: active
   AED_REAL,DIMENSION(:),INTENT(in) :: temp, salt, h, area, wnd, rain
   AED_REAL,DIMENSION(:),INTENT(in) :: rho, extcoeff, I_0, longwave, par, tss
   AED_REAL,DIMENSION(:),INTENT(in) :: rainloss, air_temp, humidity, bathy
   AED_REAL :: col_taub
!
!LOCALS
   INTEGER :: col, zon
!
!-------------------------------------------------------------------------------
!BEGIN
   zone_area = zero_
   zone_temp = zero_
   zone_salt = zero_
   zone_rho    = zero_
   zone_height = zero_
   zone_extc   = zero_
   zone_tss = zero_
   zone_par = zero_
   zone_wind = zero_
   zone_rain = zero_
   zone_rainloss = zero_
   zone_air_temp = zero_
   zone_humidity = zero_
   zone_bathy = zero_
   zone_I_0 = zero_
   zone_longwave = zero_
   zone_taub = col_taub
   zone_count = 0

   DO col=1, nCols
      zon = zm(col)
! if (zone(zon) == 11) &
! print*,"ZoneIDX ",zon," zone = ",zone(zon)," Col ",col," area col ",area(col),"TEMP ",temp(col)," is ",active(col)

      IF (.NOT. active(col)) CYCLE

      zone_area(zon)     = zone_area(zon) + area(col)
      zone_temp(zon)     = zone_temp(zon) + temp(col)
      zone_salt(zon)     = zone_salt(zon) + salt(col)
      zone_rho(zon)      = zone_rho(zon) + rho(col)
      zone_height(zon)   = zone_height(zon) + h(col)
      zone_extc(zon)     = zone_extc(zon) + extcoeff(col)
      zone_tss(zon)      = zone_tss(zon) + tss(col)
      zone_par(zon)      = zone_par(zon) + par(col)
      zone_wind(zon)     = zone_wind(zon) + wnd(col)
      zone_rain(zon)     = zone_rain(zon) + rain(col)
      zone_rainloss(zon) = zone_rainloss(zon) + rainloss(col)
      zone_air_temp(zon) = zone_air_temp(zon) + air_temp(col)
      zone_humidity(zon) = zone_humidity(zon) + humidity(col)
      zone_bathy(zon)    = zone_bathy(zon) + bathy(col)
      zone_I_0(zon)      = zone_I_0(zon) + I_0(col)
      zone_longwave(zon) = zone_longwave(zon) + longwave(col)
!     zone_taub(zon)     = zone_taub(zon) + col_taub

      zone_count(zon) = zone_count(zon) + 1
   ENDDO

   zone_temp = zone_temp / zone_count
   zone_salt = zone_salt / zone_count

   zone_rho  =  zone_rho / zone_count
   zone_extc = zone_extc / zone_count
   zone_tss  =  zone_tss / zone_count
   zone_par  =  zone_par / zone_count

   !# non-PAR light fudge
   zone_nir = (zone_par/0.45) * 0.510
   zone_uva = (zone_par/0.45) * 0.035
   zone_uvb = (zone_par/0.45) * 0.005

   zone_wind     =     zone_wind / zone_count
   zone_rain     =     zone_rain / zone_count
   zone_rainloss = zone_rainloss / zone_count
   zone_air_temp = zone_air_temp / zone_count
   zone_humidity = zone_humidity / zone_count
   zone_bathy    =    zone_bathy / zone_count
   zone_I_0      =      zone_I_0 / zone_count
   zone_longwave = zone_longwave / zone_count
!  zone_taub     =     zone_taub / zone_count

   do zon=1,nZones
! print*,"zoneidx ",zon," zone ",zone(zon)," count ",zone_count(zon)
      if (zone_count(zon) == 0) then
         zone_area(zon)     = 0.0
         zone_temp(zon)     = 0.0
         zone_salt(zon)     = 0.0
         zone_rho(zon)      = 0.0
         zone_height(zon)   = 0.0
         zone_extc(zon)     = 0.0
         zone_tss(zon)      = 0.0
         zone_par(zon)      = 0.0
         zone_wind(zon)     = 0.0
         zone_rain(zon)     = 0.0
         zone_rainloss(zon) = 0.0
         zone_air_temp(zon) = 0.0
         zone_humidity(zon) = 0.0
         zone_bathy(zon)    = 0.0
         zone_I_0(zon)      = 0.0
         zone_longwave(zon) = 0.0
!        zone_taub(zon)     = 0.0
      endif
   end do
! pause
END SUBROUTINE calc_zone_areas
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


!###############################################################################
SUBROUTINE copy_to_zone(nCols, cc, cc_diag, area, active, benth_map)
!-------------------------------------------------------------------------------
!ARGUMENTS
   INTEGER,INTENT(in)  :: nCols
   AED_REAL,INTENT(in) :: cc(:,:)       !# (n_vars, n_layers)
   AED_REAL,INTENT(in) :: cc_diag(:,:)  !# (n_vars, n_layers)
   AED_REAL,DIMENSION(:),INTENT(in) :: area
   LOGICAL,DIMENSION(:), INTENT(in) :: active
   INTEGER,DIMENSION(:), INTENT(in) :: benth_map
!
!LOCALS
   INTEGER :: col, zon, bot, v
   AED_REAL :: ta(nwq_var+nben_var)
   AED_REAL :: da(ndiag_var)
   AED_REAL :: fa
!
!-------------------------------------------------------------------------------
!BEGIN
   zone_cc = zero_
   zone_cc_diag = zero_

   DO zon=1,nZones
      ta = 0. ; da = 0.
      DO col=1, nCols
         IF ( active(col) .AND. (zon == zm(col)) ) THEN
            bot = benth_map(col)
            fa = area(col) / zone_area(zon)

            ta = ta + (cc(1:nwq_var+nben_var,bot) * fa)
            da = da + (cc_diag(:,bot) * fa)
         ENDIF
      ENDDO
      zone_cc(1:nwq_var+nben_var,zon) = ta
      zone_cc_diag(:,zon) = da
   ENDDO
END SUBROUTINE copy_to_zone
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


!###############################################################################
! Copies the diagnostic variables from the zones to the main data block
SUBROUTINE copy_from_zone(nCols, n_aed_vars, cc_diag, active, benth_map)
!-------------------------------------------------------------------------------
!ARGUMENTS
   INTEGER,INTENT(in)     :: nCols, n_aed_vars
   AED_REAL,INTENT(out)   :: cc_diag(:,:)  !# (n_vars, n_layers)
   LOGICAL,DIMENSION(:), INTENT(in) :: active
   INTEGER,DIMENSION(:), INTENT(in) :: benth_map
!
!LOCALS
   INTEGER :: col, zon, bot, i, j
   TYPE(aed_variable_t),POINTER :: tvar
!
!-------------------------------------------------------------------------------
!BEGIN
   DO col=1, nCols
      IF (.NOT. active(col)) CYCLE

      bot = benth_map(col)
      zon = zm(col)

      !# only want the diag vars that have zavg == true
      !    cc_diag(:,bot) = zone_cc_diag(:,zon)
      j = 0
      DO i=1,n_aed_vars
         IF ( aed_get_var(i, tvar) ) THEN
            IF ( tvar%diag ) THEN
               j = j + 1
               IF ( tvar%zavg ) cc_diag(j,bot) = zone_cc_diag(j,zon)
            ENDIF
         ENDIF
      ENDDO
   ENDDO
END SUBROUTINE copy_from_zone
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


!###############################################################################
SUBROUTINE STOPIT(message)
!-------------------------------------------------------------------------------
!ARGUMENTS
   CHARACTER(*) :: message
!-------------------------------------------------------------------------------
   PRINT *,message
   STOP "Fatal Error"
END SUBROUTINE STOPIT
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


!###############################################################################
SUBROUTINE define_column_zone(column, zon, n_aed_vars)!, n_vars)
!-------------------------------------------------------------------------------
!ARGUMENTS
   TYPE (aed_column_t), INTENT(inout) :: column(:)
   INTEGER, INTENT(in) :: zon, n_aed_vars!, n_vars
!
!LOCALS
   INTEGER :: av, i !, top, bot
   INTEGER :: v, d, sv, sd, ev
   TYPE(aed_variable_t),POINTER :: tvar
!
!-------------------------------------------------------------------------------
!BEGIN
   v = 0 ; d = 0; sv = 0; sd = 0 ; ev = 0
   DO av=1,n_aed_vars

      IF ( .NOT. aed_get_var(av, tvar) ) STOP "Error getting variable info"

      IF ( tvar%extern ) THEN !# global variable
         ev = ev + 1
         SELECT CASE (tvar%name)
            CASE ( 'temperature' ) ; column(av)%cell => zone_temp
            CASE ( 'salinity' )    ; column(av)%cell => zone_salt
            CASE ( 'density' )     ; column(av)%cell => zone_rho
            CASE ( 'layer_ht' )    ; column(av)%cell => zone_height
            CASE ( 'layer_area' )  ; column(av)%cell_sheet => zone_area(zon)
            CASE ( 'rain' )        ; column(av)%cell_sheet => zone_rain(zon)
            CASE ( 'rainloss' )    ; column(av)%cell_sheet => zone_rainloss(zon)
            CASE ( 'material' )    ; column(av)%cell_sheet => zone(zon)
            CASE ( 'bathy' )       ; column(av)%cell_sheet => zone_bathy(zon)
            CASE ( 'extc_coef' )   ; column(av)%cell => zone_extc
            CASE ( 'tss' )         ; column(av)%cell => zone_tss
            CASE ( 'par' )         ; column(av)%cell => zone_par
            CASE ( 'cell_vel' )    ; column(av)%cell => null() ! zone_cvel
            CASE ( 'nir' )         ; column(av)%cell => zone_nir
            CASE ( 'uva' )         ; column(av)%cell => zone_uva
            CASE ( 'uvb' )         ; column(av)%cell => zone_uvb
            CASE ( 'sed_zone' )    ; column(av)%cell_sheet => zone(zon)
            CASE ( 'wind_speed' )  ; column(av)%cell_sheet => zone_wind(zon)
            CASE ( 'par_sf' )      ; column(av)%cell_sheet => zone_I_0(zon)
            CASE ( 'taub' )        ; column(av)%cell_sheet => zone_taub
            CASE ( 'air_temp' )    ; column(av)%cell_sheet => zone_air_temp(zon)
            CASE ( 'humidity' )    ; column(av)%cell_sheet => zone_humidity(zon)
            CASE ( 'longwave' )    ; column(av)%cell_sheet => zone_longwave(zon)
            CASE ( 'col_num' )     ; column(av)%cell_sheet => zone_colnums(zon)

            CASE ( 'nearest_active' ) ; column(av)%cell_sheet => null() ! zone_nearest_active(col);
            CASE ( 'nearest_depth' )  ; column(av)%cell_sheet => null() ! zone_nearest_depth(col);
            CASE DEFAULT ; CALL STOPIT("ERROR: external variable "//trim(tvar%name)//" not found.")
         END SELECT
      ELSEIF ( tvar%diag ) THEN  !# Diagnostic variable
         d = d + 1
         IF ( tvar%sheet ) THEN
            column(av)%cell_sheet => zone_cc_diag(d,zon)
         ELSE
            column(av)%cell => zone_cc_diag(d,zon:zon)
         ENDIF
      ELSE    !# state variable
         IF ( tvar%sheet ) THEN
            sv = sv + 1
            IF ( tvar%bot ) THEN
               column(av)%cell_sheet => zone_cc(nwq_var+sv, zon)
            ELSEIF ( tvar%top ) THEN
    !          column(av)%cell_sheet => zone_cc(nwq_var+sv, top)
            ENDIF
            column(av)%flux_ben => flux_benz(nwq_var+sv, zon)
    !       column(av)%flux_atm => flux_atm(nwq_var+sv)
         ELSE
            v = v + 1
            column(av)%cell => zone_cc(v, zon:zon)
            column(av)%flux_pel => flux_pelz(v, zon:zon)
            column(av)%flux_ben => flux_benz(v, zon)
    !       column(av)%flux_atm => flux_atm(v)
         ENDIF
      ENDIF
   ENDDO
END SUBROUTINE define_column_zone
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


!###############################################################################
SUBROUTINE aed_initialize_zone_benthic(nCols, active, n_aed_vars, cc_diag, benth_map)
!-------------------------------------------------------------------------------
!ARGUMENTS
   INTEGER,INTENT(in)   :: nCols
   LOGICAL,DIMENSION(:),INTENT(in) :: active
   INTEGER,INTENT(in)   :: n_aed_vars
   AED_REAL,INTENT(out) :: cc_diag(:,:)
   INTEGER,DIMENSION(:),INTENT(in) :: benth_map
!
!LOCALS
   INTEGER :: col, zon, bot
   TYPE (aed_column_t) :: column(n_aed_vars)
!
!-------------------------------------------------------------------------------
!BEGIN
   DO zon=1, nZones
      zone_cc_diag(:,zon) = zero_

      CALL define_column_zone(column, zon, n_aed_vars)

      CALL aed_initialize_benthic(column, 1)
   ENDDO

   CALL copy_from_zone(nCols, n_aed_vars, cc_diag, active, benth_map)
   !# now copy the diagnostic vars back
!  DO col=1, nCols
!     IF (.NOT. active(col)) CYCLE

!     bot = benth_map(col)
!     zon = zm(col)

!     cc_diag(:,bot) = zone_cc_diag(:,zon)
!  ENDDO
END SUBROUTINE aed_initialize_zone_benthic
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


!###############################################################################
SUBROUTINE compute_zone_benthic_fluxes(n_aed_vars)
!-------------------------------------------------------------------------------
!ARGUMENTS
   INTEGER,INTENT(in) :: n_aed_vars
!
!LOCALS
   INTEGER :: zon, v
   TYPE (aed_column_t) :: column(n_aed_vars)
!
!-------------------------------------------------------------------------------
!BEGIN
   flux_pelz = zero_ ; flux_benz = zero_
!!$OMP DO PRIVATE(zon,column)
   DO zon=1, nZones
      CALL define_column_zone(column, zon, n_aed_vars)

      CALL aed_calculate_benthic(column, 1, .TRUE.)
   ENDDO
!!$OMP END DO
END SUBROUTINE compute_zone_benthic_fluxes
!+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++


!===============================================================================
END MODULE fv_zones
